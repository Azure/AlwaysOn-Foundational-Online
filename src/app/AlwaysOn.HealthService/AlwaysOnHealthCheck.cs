﻿using AlwaysOn.Shared;
using AlwaysOn.Shared.Interfaces;
using Azure;
using Azure.Identity;
using Azure.Monitor.Query;
using Azure.Monitor.Query.Models;
using Azure.Storage.Blobs;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace AlwaysOn.HealthService
{
    public class AlwaysOnHealthCheck : IHealthCheck
    {
        private const string STATE_BLOB_CACHE_KEY = "stateBlobHealth";
        private const string STATE_MESSAGE_PRODUCER_CACHE_KEY = "stateMessageProducerHealth";
        private const string STATE_DATABASE_CACHE_KEY = "stateDatabaseHealth";
        private const string STATE_AZMONITOR_CACHE_KEY = "stateAzMonitorHealth";

        // If the HealthScore as returned by the Az Monitor query is equal or less than this, the stamp is considered unhealthy
        private const double HEALTHSCORE_THRESHOLD = 0.5;

        private readonly ILogger<AlwaysOnHealthCheck> _log;
        private readonly SysConfiguration _sysConfig;
        private readonly IDatabaseService _databaseService;
        private readonly IMessageProducerService _messageProducerService;
        private IMemoryCache _cache;

        public AlwaysOnHealthCheck(ILogger<AlwaysOnHealthCheck> log,
            SysConfiguration sysConfig,
            IMemoryCache memoryCache,
            IDatabaseService databaseService,
            IMessageProducerService messageProducerService)
        {
            _log = log;
            _sysConfig = sysConfig;
            _cache = memoryCache;
            _databaseService = databaseService;
            _messageProducerService = messageProducerService;
        }

        /// <summary>
        /// Checks downstream dependencies like Message Producer and database service for their health
        /// Also, checks the state blob storage
        /// Uses caching in order not to overload the components just with health checks
        /// </summary>
        /// <param name="context"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public async Task<HealthCheckResult> CheckHealthAsync(
            HealthCheckContext context,
            CancellationToken cancellationToken = default(CancellationToken))
        {
            // Check state blob
            var stateBlobIsHealthyTask = _cache.GetOrCreateAsync(STATE_BLOB_CACHE_KEY, entry =>
            {
                var result = GetStateBlobHealth(cancellationToken);
                _log.LogDebug("Probing state blob health state - Cache empty or expired");
                entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromSeconds(_sysConfig.HealthServiceCacheDurationSeconds);
                return result;
            });

            // Check message sending
            var messageProducerIsHealthyTask = _cache.GetOrCreateAsync(STATE_MESSAGE_PRODUCER_CACHE_KEY, entry =>
            {
                var result = _messageProducerService.IsHealthy(cancellationToken);
                _log.LogDebug("Probing message producer health state - Cache empty or expired");
                entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromSeconds(_sysConfig.HealthServiceCacheDurationSeconds);
                return result;
            });

            // Check database querying
            var databaseIsHealthyTask = _cache.GetOrCreateAsync(STATE_DATABASE_CACHE_KEY, entry =>
            {
                var result = _databaseService.IsHealthy(cancellationToken);
                _log.LogDebug("Probing database health state - Cache empty or expired");
                entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromSeconds(_sysConfig.HealthServiceCacheDurationSeconds);
                return result;
            });

            // Check Az Monitor for stamp HealthScore
            var azMonitorIsHealthyTask = _cache.GetOrCreateAsync(STATE_AZMONITOR_CACHE_KEY, entry =>
            {
                var result = GetStampHealthFromAzMonitor(cancellationToken);
                _log.LogDebug("Probing Azure Monitor for stamp HealthScore - Cache empty or expired");
                entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromSeconds(_sysConfig.HealthServiceCacheDurationSeconds);
                return result;
            });

            var checkTasks = new[] { stateBlobIsHealthyTask, messageProducerIsHealthyTask, databaseIsHealthyTask, azMonitorIsHealthyTask };

            // Run all checks in parallel
            await Task.WhenAll(checkTasks);

            var props = new Dictionary<string, object>
            {
                { "StateBlobHealthy", stateBlobIsHealthyTask.Result },
                { "MessageProducerServiceHealthy", messageProducerIsHealthyTask.Result },
                { "DatabaseServiceHealthy", databaseIsHealthyTask.Result },
                { "StampHealthScoreOk", azMonitorIsHealthyTask.Result }
            };

            // If any one of the checks is false (= unhealthy), report overall unhealthy
            if (checkTasks.Any(t => t.Result == false))
            {
                return HealthCheckResult.Unhealthy(data: props);
            }

            return HealthCheckResult.Healthy(data: props);
        }

        /// <summary>
        /// Checks whether the state file on blob storage exists. File exists means: Healthy
        /// </summary>
        /// <returns>True=HEALTHY, False=UNHEALTHY</returns>
        private async Task<bool> GetStateBlobHealth(CancellationToken cancellationToken = default(CancellationToken))
        {
            try
            {
                var blobContainerClient = new BlobContainerClient(_sysConfig.HealthServiceStorageConnectionString, _sysConfig.HealthServiceBlobContainerName);
                _log.LogDebug("Initiated health state blob container client at {HealthBlobContainerUrl}", blobContainerClient.Uri.ToString());

                var stateBlobClient = blobContainerClient.GetBlobClient(_sysConfig.HealthServiceBlobName);
                return await stateBlobClient.ExistsAsync(cancellationToken);

                /*
                 * As an alternative to just checking for the file's existence, we could also examine the file's content for specfic states
                 * For example: "HEALTHY, UNHEALTHY, MAINTENANCE"
                 * 
                var download = await stateBlobClient.DownloadAsync(cancellationToken);
                StreamReader reader = new StreamReader(download.Value.Content);
                string text = reader.ReadToEnd();

                _log.LogDebug("State blob '{stateBlobName}' present. Content: {state}", _stateBlobName, text);
                return text == "HEALTHY";
                */
            }
            catch (Exception e)
            {
                // If the file does not exist or we cannot reach our storage at all, we treat this a an unhealthy state
                // as well as it might very well mean that storage in that region has an issue.
                _log.LogError(e, "Could not check health state blob. Responding with UNHEALTHY state");
                return false;
            }
        }

        /// <summary>
        /// Query regional Log Analytics workspace to fetch the latest HealthScore
        /// </summary>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        private async Task<bool> GetStampHealthFromAzMonitor(CancellationToken cancellationToken = default(CancellationToken))
        {
            try
            {
                var client = new LogsQueryClient(new DefaultAzureCredential(new DefaultAzureCredentialOptions()
                {
                    ManagedIdentityClientId = _sysConfig.ManagedIdentityClientId
                }));

                Response<LogsQueryResult> response = await client.QueryWorkspaceAsync(
                    _sysConfig.RegionalLogAnalyticsWorkspaceId,
                    "StampHealthScore | project TimeGenerated,HealthScore | order by TimeGenerated desc | take 1",
                    new QueryTimeRange(TimeSpan.FromMinutes(10)),
                    cancellationToken: cancellationToken);

                LogsTable table = response.Value.Table;

                foreach (var row in table.Rows) // there will be only one row (take 1)
                {
                    var healthScore = row.GetDouble("HealthScore");
                    _log.LogDebug($"TimeGenerated: [{row["TimeGenerated"]}] HealthScore: {healthScore}");
                    // If the healthscore indicates red, return false
                    if (healthScore <= HEALTHSCORE_THRESHOLD)
                    {
                        _log.LogInformation($"HealthScore of {healthScore} is <= {HEALTHSCORE_THRESHOLD}. Reporting stamp as unhealty!");
                        return false;
                    }
                }
            }
            catch (Exception e)
            {
                _log.LogError(e, "Could not query Log Analytics health score. Responding with UNHEALTHY state");
                return false;
            }
            return true;
        }
    }
}
