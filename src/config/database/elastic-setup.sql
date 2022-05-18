/* 
Query across databases with different schemas: https://docs.microsoft.com/en-us/azure/azure-sql/database/elastic-query-vertical-partitioning 
    - doesn't require shard map
    - currently using this

Query across databases with the same schema: https://docs.microsoft.com/en-us/azure/azure-sql/database/elastic-query-horizontal-partitioning
    - requires shard map
*/

---
--- User account provisioning.
---
CREATE LOGIN CrossDb WITH PASSWORD = 'N/A';     -- on master of stamp1
SELECT sid FROM sys.sql_logins WHERE NAME = 'CrossDb';  -- get SID from the primary database
-- '0x010600000000006400000000000000007A78DFAA5CB0B94E8939BF17DB918A7D'

-- without this, cross db query fails on insufficient permissions
CREATE LOGIN CrossDb WITH PASSWORD = 'N/A', sid=0x010600000000006400000000000000007A78DFAA5CB0B94E8939BF17DB918A7D; -- on master of stamp2 and stamp3

CREATE USER CrossDb FROM LOGIN CrossDb;             -- on primary database for each stamp
EXEC sp_addRoleMember 'db_owner', 'CrossDb';        -- on primary database for each stamp
-- EXEC sp_addrolemember 'db_datareader', 'CrossDb';
GO


---
--- Elastic Query base setup
---
CREATE MASTER KEY;
GO

CREATE DATABASE SCOPED CREDENTIAL CrossDbCred WITH IDENTITY = 'CrossDb', SECRET = 'N/A';
GO

--- The following should be run against maindbstamp1.

---
--- Configure stamp2 external source and tables.
---

--- Data source - make sure that the database was actually replicated to this server (can take some time)
CREATE EXTERNAL DATA SOURCE stamp2db
WITH
(
    TYPE = RDBMS,
    LOCATION = 'martinstamp1.database.windows.net',
    DATABASE_NAME = 'maindbstamp2',
    CREDENTIAL = CrossDbCred
);
GO

--- CatalogItems - external table based on the data source from stamp 2
CREATE EXTERNAL TABLE [ao].[CatalogItemsStamp2]
(
    [Id] UNIQUEIDENTIFIER,
    [Name] NVARCHAR(50) NOT NULL,
    [Description] NVARCHAR(500) NOT NULL,
    [ImageUrl] NVARCHAR(100) NOT NULL,
    [Price] DECIMAL(10,2) NOT NULL,
    [LastUpdated] DATETIME NOT NULL,
    [Rating] FLOAT,
    [CreationDate] DATETIME2(7) NOT NULL
)
WITH
(
    DATA_SOURCE = stamp2db,
    SCHEMA_NAME = 'ao',
    OBJECT_NAME = 'CatalogItems'
)
GO

CREATE EXTERNAL TABLE [ao].[RatingsStamp2]
(
    [Id] UNIQUEIDENTIFIER,
    [CatalogItemId] UNIQUEIDENTIFIER NOT NULL,
    [Rating] INT NOT NULL,
    [CreationDate] DATETIME2(7) NOT NULL,
)
WITH
(
    DATA_SOURCE = stamp2db,
    SCHEMA_NAME = 'ao',
    OBJECT_NAME = 'Ratings'
)
GO

CREATE EXTERNAL TABLE [ao].[CommentsStamp2]
(
    [Id] UNIQUEIDENTIFIER,
    [CatalogItemId] UNIQUEIDENTIFIER NOT NULL,
    [AuthorName] NVARCHAR(50) NOT NULL,
    [Text] NVARCHAR(500) NOT NULL,
    [CreationDate] DATETIME2(7) NOT NULL
)
WITH
(
    DATA_SOURCE = stamp2db,
    SCHEMA_NAME = 'ao',
    OBJECT_NAME = 'Comments'
)
GO

---
--- Configure stamp3 external source and tables.
---

--- Data source
CREATE EXTERNAL DATA SOURCE stamp3db
WITH
(
    TYPE = RDBMS,
    LOCATION = 'martinstamp1.database.windows.net',
    DATABASE_NAME = 'maindbstamp3',
    CREDENTIAL = CrossDbCred
);
GO

select * from sys.external_data_sources;
GO


--- CatalogItems - external table based on the data source from stamp 3
CREATE EXTERNAL TABLE [ao].[CatalogItemsStamp3]
(
    [Id] UNIQUEIDENTIFIER,
    [Name] NVARCHAR(50) NOT NULL,
    [Description] NVARCHAR(500) NOT NULL,
    [ImageUrl] NVARCHAR(100) NOT NULL,
    [Price] DECIMAL(10,2) NOT NULL,
    [LastUpdated] DATETIME NOT NULL,
    [Rating] FLOAT,
    [CreationDate] DATETIME2(7) NOT NULL
)
WITH
(
    DATA_SOURCE = stamp3db,
    SCHEMA_NAME = 'ao',
    OBJECT_NAME = 'CatalogItems'
)
GO

CREATE EXTERNAL TABLE [ao].[RatingsStamp3]
(
    [Id] UNIQUEIDENTIFIER,
    [CatalogItemId] UNIQUEIDENTIFIER NOT NULL,
    [Rating] INT NOT NULL,
    [CreationDate] DATETIME2(7) NOT NULL
)
WITH
(
    DATA_SOURCE = stamp3db,
    SCHEMA_NAME = 'ao',
    OBJECT_NAME = 'Ratings'
)
GO

CREATE EXTERNAL TABLE [ao].[CommentsStamp3]
(
    [Id] UNIQUEIDENTIFIER,
    [CatalogItemId] UNIQUEIDENTIFIER NOT NULL,
    [AuthorName] NVARCHAR(50) NOT NULL,
    [Text] NVARCHAR(500) NOT NULL,
    [CreationDate] DATETIME2(7) NOT NULL
)
WITH
(
    DATA_SOURCE = stamp3db,
    SCHEMA_NAME = 'ao',
    OBJECT_NAME = 'Comments'
)
GO


---
--- Create a view to get all data from stamp 1 (master plus replicas)
---
CREATE VIEW [ao].[AllCatalogItems] AS
    SELECT * FROM [ao].[CatalogItems]
    UNION ALL
    SELECT * FROM [ao].[CatalogItemsStamp2]
    UNION ALL
    SELECT * FROM [ao].[CatalogItemsStamp3]
GO

CREATE VIEW [ao].[LatestCatalogItems] AS
    -- https://stackoverflow.com/questions/28722276/sql-select-top-1-for-each-group
    SELECT TOP 1 WITH TIES 
            [Id],
            [Name],
            [Description],
            [ImageUrl],
            [Price],
            [LastUpdated],
            [Rating],
            [CreationDate] FROM (
        SELECT * FROM [ao].[CatalogItems]
        UNION ALL
        SELECT * FROM [ao].[CatalogItemsStamp2]
        UNION ALL
        SELECT * FROM [ao].[CatalogItemsStamp3]
    ) AS u
    ORDER BY
        ROW_NUMBER() OVER(PARTITION BY Id ORDER BY [CreationDate] DESC);
GO

-- There's no update on comments and ratings, so we can keep them simple.
CREATE VIEW [ao].[AllRatings] AS
    SELECT * FROM [ao].[Ratings]
    UNION ALL
    SELECT * FROM [ao].[RatingsStamp2]
    UNION ALL
    SELECT * FROM [ao].[RatingsStamp3]
GO

CREATE VIEW [ao].[AllComments] AS
    SELECT * FROM [ao].[Comments]
    UNION ALL
    SELECT * FROM [ao].[CommentsStamp2]
    UNION ALL
    SELECT * FROM [ao].[CommentsStamp3]
GO

---
--- Check if the view works
---
SELECT * FROM [ao].AllCatalogItems

SELECT * FROM [ao].LatestCatalogItems