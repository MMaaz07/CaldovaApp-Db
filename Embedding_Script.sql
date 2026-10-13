/* =====================================================================================

   Caldova Order Management - Generate Vector Embeddings for Product Descriptions

   =====================================================================================

   Target database : CaldovaOrderManagement (Azure SQL Database Hyperscale)
 
   This script processes ALL not-yet-embedded product descriptions in a SINGLE

   execution - no re-running/clicking "Run" multiple times required.
 
   To stay fast enough to avoid client-side "Execution Timeout Expired" errors, it

   groups products into internal CHUNKS of @ChunkSize (default 16) and makes ONE

   gpt-5-mini call and ONE text-embedding-ada-002 call per chunk (each call carries

   the whole chunk's items as a JSON array), instead of one call per product. For 140

   products that's ~9 chunks x 2 calls = ~18 external calls total (well under a minute),

   instead of 280 individual calls (several minutes) - which is what caused the

   previous "Execution Timeout Expired" / HRESULT 0x80072efe errors: those weren't SQL

   errors, they were the client giving up waiting for a long-running script to finish.
 
   It is still idempotent/safe to re-run (already-embedded rows are skipped via a

   NOT EXISTS filter), in case a transient failure leaves a few rows unembedded.
 
   Models used (both attached to openai-2398106, as required):

     - gpt-5-mini             -> enriches each product's structured description into a

                                  short natural-language "use case" summary (one call

                                  handles a whole chunk of products at once).

     - text-embedding-ada-002 -> embeds the enriched text into a 1536-dimension vector

                                  (one call embeds a whole chunk's texts at once, via

                                  the embeddings API's array "input" support).
 
   SECURITY NOTE: replace the '<AZURE_OPENAI_API_KEY>' placeholder below with the actual

   key before running, and never commit the real key to source control.

   ===================================================================================== */
 
SET NOCOUNT ON;

GO
 
------------------------------------------------------------------------------

-- 0. Configuration - declared ONCE here and referenced everywhere below.

--    Nothing else in this script hardcodes the endpoint, API key, or model names.

------------------------------------------------------------------------------

DECLARE @AOAI_Endpoint SYSNAME = N'<AZURE_OPENAI_ENDPOINT>';

DECLARE @AOAI_APIkey NVARCHAR(400) = N'<AZURE_OPENAI_API_KEY>';

DECLARE @GPT_Model NVARCHAR(200) = N'<GPT_MODEL>';

DECLARE @Embedding_Model NVARCHAR(200) = N'<EMBEDDING_MODEL>';

DECLARE @ChunkSize INT = 16; -- products per external call; lower this if you hit token limits

DECLARE @MasterKeyPassword NVARCHAR(200) = N'Ch4ng3-This-Master-Key-Password!';
 
DECLARE @ChatUrl NVARCHAR(4000) = @AOAI_Endpoint + N'/openai/deployments/' + @GPT_Model + N'/chat/completions?api-version=2024-08-01-preview';

DECLARE @EmbeddingUrl NVARCHAR(4000) = @AOAI_Endpoint + N'/openai/deployments/' + @Embedding_Model + N'/embeddings?api-version=2023-05-15';
 
DECLARE @sql NVARCHAR(MAX);
 
------------------------------------------------------------------------------

-- 1. Database master key (required to protect the scoped credential's secret).

--    CREATE MASTER KEY's PASSWORD clause only accepts a literal, so it is built

--    via dynamic SQL to keep @MasterKeyPassword as the single source of truth.

------------------------------------------------------------------------------

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')

BEGIN

    SET @sql = N'CREATE MASTER KEY ENCRYPTION BY PASSWORD = ''' + REPLACE(@MasterKeyPassword, '''', '''''') + N'''';

    EXEC sp_executesql @sql;

END
 
------------------------------------------------------------------------------

-- 2. Database scoped credential for the Azure OpenAI REST endpoint.

--    CREATE/DROP CREDENTIAL don't accept variables for the object name or SECRET

--    directly, so both are built via dynamic SQL from @AOAI_Endpoint/@AOAI_APIkey -

--    the literal values themselves only ever appear in section 0 above.

------------------------------------------------------------------------------

IF EXISTS (SELECT 1 FROM sys.database_scoped_credentials WHERE name = @AOAI_Endpoint)

BEGIN

    SET @sql = N'DROP DATABASE SCOPED CREDENTIAL ' + QUOTENAME(@AOAI_Endpoint);

    EXEC sp_executesql @sql;

END
 
SET @sql = N'CREATE DATABASE SCOPED CREDENTIAL ' + QUOTENAME(@AOAI_Endpoint) +

           N' WITH IDENTITY = ''HTTPEndpointHeaders'', SECRET = ''{"api-key":"' +

           REPLACE(@AOAI_APIkey, '''', '''''') + N'"}''';

EXEC sp_executesql @sql;
 
------------------------------------------------------------------------------

-- 3. Ensure the embeddings table exists (dimension 1536 matches text-embedding-ada-002)

------------------------------------------------------------------------------

IF OBJECT_ID('dbo.ProductDescriptionEmbeddings', 'U') IS NULL

BEGIN

    CREATE TABLE dbo.ProductDescriptionEmbeddings

    (

        ProductDescriptionEmbeddingID INT IDENTITY(1,1) NOT NULL

            CONSTRAINT PK_ProductDescriptionEmbeddings PRIMARY KEY,

        ProductID INT NOT NULL

            CONSTRAINT FK_ProductDescriptionEmbeddings_Product REFERENCES dbo.ProductCatalog (ProductID),

        ProductDescriptionID INT NOT NULL

            CONSTRAINT FK_ProductDescriptionEmbeddings_ProductDescription REFERENCES dbo.ProductDescriptions (ProductDescriptionID),

        ContentText NVARCHAR(MAX) NOT NULL,

        Embedding VECTOR(1536) NOT NULL,

        CreatedDate DATETIME2(0) NOT NULL CONSTRAINT DF_ProductDescriptionEmbeddings_CreatedDate DEFAULT (SYSDATETIME()),

        ModifiedDate DATETIME2(0) NOT NULL CONSTRAINT DF_ProductDescriptionEmbeddings_ModifiedDate DEFAULT (SYSDATETIME()),

        CONSTRAINT UQ_ProductDescriptionEmbeddings_ProductDescription UNIQUE (ProductDescriptionID)

    );

END
 
------------------------------------------------------------------------------

-- 4. Process ALL not-yet-embedded product descriptions in this single execution.

--    Internally grouped into chunks of @ChunkSize so each external call handles many

--    products at once (fast), while every row still gets embedded before this batch ends.

--    (Uses the @AOAI_Endpoint / @ChatUrl / @EmbeddingUrl variables declared in section 0 -

--    no endpoint/key/model literals are repeated here.)

------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#Source') IS NOT NULL DROP TABLE #Source;
 
SELECT

    pd.ProductDescriptionID,

    pd.ProductID,

    p.ProductName,

    CONCAT(

        p.ProductName, N' (SKU ', p.SKU, N')',

        N' | Category: ', c.CategoryName,

        CASE WHEN pd.ShortDescription IS NOT NULL THEN N' | ' + pd.ShortDescription ELSE N'' END,

        CASE WHEN pd.LongDescription IS NOT NULL THEN N' | ' + pd.LongDescription ELSE N'' END,

        CASE WHEN pd.Specifications IS NOT NULL THEN N' | ' + pd.Specifications ELSE N'' END

    ) AS BaseContentText,

    CAST(NULL AS NVARCHAR(MAX)) AS UseCaseSummary,

    (ROW_NUMBER() OVER (ORDER BY pd.ProductDescriptionID) - 1) / @ChunkSize AS ChunkNumber,

    CAST(0 AS INT) AS ItemIndex -- 0-based position within its chunk; filled in below

INTO #Source

FROM dbo.ProductDescriptions pd

JOIN dbo.ProductCatalog p ON p.ProductID = pd.ProductID

JOIN dbo.ProductCategories c ON c.CategoryID = p.CategoryID

WHERE pd.LanguageCode = 'en-US'

  AND NOT EXISTS (

        SELECT 1 FROM dbo.ProductDescriptionEmbeddings e

        WHERE e.ProductDescriptionID = pd.ProductDescriptionID

      );
 
;WITH Numbered AS (

    SELECT ProductDescriptionID, ROW_NUMBER() OVER (PARTITION BY ChunkNumber ORDER BY ProductDescriptionID) - 1 AS Idx

    FROM #Source

)

UPDATE s SET s.ItemIndex = n.Idx

FROM #Source s JOIN Numbered n ON n.ProductDescriptionID = s.ProductDescriptionID;
 
SELECT TotalToEmbed = COUNT(*), TotalChunks = COUNT(DISTINCT ChunkNumber) FROM #Source;
 
------------------------------------------------------------------------------

-- 4a/4b. Per chunk: one gpt-5-mini call to enrich the whole chunk, then one

--        text-embedding-ada-002 call to embed the whole chunk, then upsert.

------------------------------------------------------------------------------

DECLARE @ChunkCount INT = (SELECT ISNULL(MAX(ChunkNumber), -1) + 1 FROM #Source);

DECLARE @Chunk INT = 0;

DECLARE @Attempt INT, @MaxAttempts INT = 4;
 
DECLARE @ChatItemsJson NVARCHAR(MAX), @ChatPayload NVARCHAR(MAX), @ChatResponse NVARCHAR(MAX), @ChatReturnValue INT;

DECLARE @ChatContent NVARCHAR(MAX);

DECLARE @EmbedInputArray NVARCHAR(MAX), @EmbedPayload NVARCHAR(MAX), @EmbedResponse NVARCHAR(MAX), @EmbedReturnValue INT;
 
WHILE @Chunk < @ChunkCount

BEGIN

    -- ---- 4a. gpt-5-mini: enrich every product in this chunk with ONE call ----

    SET @ChatItemsJson = (

        SELECT JSON_ARRAYAGG(JSON_OBJECT('id': ProductDescriptionID, 'name': ProductName, 'details': BaseContentText))

        FROM #Source WHERE ChunkNumber = @Chunk

    );
 
    SET @ChatPayload = JSON_OBJECT(

        'messages': JSON_ARRAY(

            JSON_OBJECT(

                'role': 'user',

                'content': CONCAT(

                    N'For each product below, write a short plain-language use-case summary (max 20 words) ',

                    N'mentioning symptoms/conditions it addresses, suitable for a natural-language product ',

                    N'search index. Return ONLY a JSON array of objects with keys ''id'' and ''summary'', no ',

                    N'other text, no markdown fences.', CHAR(10), CHAR(10), @ChatItemsJson

                )

            )

        ),

        'max_completion_tokens': 4000,

        'reasoning_effort': 'minimal'

    );
 
    SET @Attempt = 1;

    SET @ChatReturnValue = NULL;

    WHILE @Attempt <= @MaxAttempts AND @ChatReturnValue IS NULL

    BEGIN

        BEGIN TRY

            -- Connection-level failures (e.g. HRESULT 0x80072efe) raise a hard T-SQL exception

            -- rather than a non-zero return code, so TRY/CATCH + retry is required to keep going.

            EXEC @ChatReturnValue = sp_invoke_external_rest_endpoint

                @url = @ChatUrl,

                @method = 'POST',

                @credential = @AOAI_Endpoint,

                @payload = @ChatPayload,

                @retry_count = 3,

                @timeout = 90,

                @response = @ChatResponse OUTPUT;

        END TRY

        BEGIN CATCH

            PRINT CONCAT('  Chunk ', @Chunk, ' gpt-5-mini attempt ', @Attempt, ' threw: ', ERROR_MESSAGE());

            SET @ChatReturnValue = NULL;

            WAITFOR DELAY '00:00:02';

        END CATCH

        SET @Attempt += 1;

    END
 
    IF @ChatReturnValue = 0

    BEGIN

        SET @ChatContent = JSON_VALUE(@ChatResponse, '$.result.choices[0].message.content');

        -- Strip optional ```json ... ``` fences some models add despite instructions.

        SET @ChatContent = REPLACE(REPLACE(LTRIM(RTRIM(@ChatContent)), '```json', ''), '```', '');
 
        UPDATE s

        SET s.UseCaseSummary = ISNULL(j.Summary, s.ProductName)

        FROM #Source s

        JOIN OPENJSON(@ChatContent) WITH (Id INT '$.id', Summary NVARCHAR(MAX) '$.summary') AS j

            ON j.Id = s.ProductDescriptionID

        WHERE s.ChunkNumber = @Chunk;

    END

    ELSE

    BEGIN

        PRINT CONCAT('gpt-5-mini call failed for chunk ', @Chunk, ': ', ISNULL(@ChatResponse, '(no response - see exception above)'));

    END
 
    -- Fallback for any row in this chunk that still has no summary (parse failure, etc.)

    UPDATE #Source SET UseCaseSummary = ProductName WHERE ChunkNumber = @Chunk AND UseCaseSummary IS NULL;
 
    -- ---- 4b. text-embedding-ada-002: embed every product's text in this chunk with ONE call ----

    SET @EmbedInputArray = N'[' + (

        SELECT STRING_AGG('"' + STRING_ESCAPE(CONCAT(BaseContentText, N' | Use case: ', UseCaseSummary), 'json') + '"', ',')

            WITHIN GROUP (ORDER BY ItemIndex)

        FROM #Source WHERE ChunkNumber = @Chunk

    ) + N']';
 
    SET @EmbedPayload = JSON_OBJECT('input': JSON_QUERY(@EmbedInputArray));
 
    SET @Attempt = 1;

    SET @EmbedReturnValue = NULL;

    WHILE @Attempt <= @MaxAttempts AND @EmbedReturnValue IS NULL

    BEGIN

        BEGIN TRY

            EXEC @EmbedReturnValue = sp_invoke_external_rest_endpoint

                @url = @EmbeddingUrl,

                @method = 'POST',

                @credential = @AOAI_Endpoint,

                @payload = @EmbedPayload,

                @retry_count = 3,

                @timeout = 90,

                @response = @EmbedResponse OUTPUT;

        END TRY

        BEGIN CATCH

            PRINT CONCAT('  Chunk ', @Chunk, ' embedding attempt ', @Attempt, ' threw: ', ERROR_MESSAGE());

            SET @EmbedReturnValue = NULL;

            WAITFOR DELAY '00:00:02';

        END CATCH

        SET @Attempt += 1;

    END
 
    IF @EmbedReturnValue = 0

    BEGIN

        ;WITH Embeddings AS (

            SELECT

                CAST(JSON_VALUE(v.[value], '$.index') AS INT) AS ItemIndex,

                JSON_QUERY(v.[value], '$.embedding') AS EmbeddingJson

            FROM OPENJSON(@EmbedResponse, '$.result.data') AS v

        )

        MERGE dbo.ProductDescriptionEmbeddings AS target

        USING (

            SELECT s.ProductID, s.ProductDescriptionID,

                   CONCAT(s.BaseContentText, N' | Use case: ', s.UseCaseSummary) AS ContentText,

                   e.EmbeddingJson

            FROM #Source s

            JOIN Embeddings e ON e.ItemIndex = s.ItemIndex

            WHERE s.ChunkNumber = @Chunk

        ) AS src

        ON target.ProductDescriptionID = src.ProductDescriptionID

        WHEN MATCHED THEN

            UPDATE SET ContentText = src.ContentText,

                       Embedding = CAST(src.EmbeddingJson AS VECTOR(1536)),

                       ModifiedDate = SYSDATETIME()

        WHEN NOT MATCHED THEN

            INSERT (ProductID, ProductDescriptionID, ContentText, Embedding)

            VALUES (src.ProductID, src.ProductDescriptionID, src.ContentText, CAST(src.EmbeddingJson AS VECTOR(1536)));

    END

    ELSE

    BEGIN

        PRINT CONCAT('Embedding call failed for chunk ', @Chunk, ': ', ISNULL(@EmbedResponse, '(no response - see exception above)'));

    END
 
    PRINT CONCAT('Chunk ', @Chunk + 1, ' of ', @ChunkCount, ' done.');

    SET @Chunk += 1;

END
 
DROP TABLE IF EXISTS #Source;

GO
 
------------------------------------------------------------------------------

-- 5. Final verification - RemainingToEmbed should be 0 after this single execution.

--    (If a transient failure left some rows unembedded, simply re-run this script -

--    it's idempotent and will only process what's still missing.)

------------------------------------------------------------------------------

SELECT

    (SELECT COUNT(*) FROM dbo.ProductDescriptions WHERE LanguageCode = 'en-US') AS TotalProductDescriptions,

    (SELECT COUNT(*) FROM dbo.ProductDescriptionEmbeddings) AS EmbeddedSoFar,

    (SELECT COUNT(*) FROM dbo.ProductDescriptions pd

        WHERE pd.LanguageCode = 'en-US'

          AND NOT EXISTS (SELECT 1 FROM dbo.ProductDescriptionEmbeddings e WHERE e.ProductDescriptionID = pd.ProductDescriptionID)

    ) AS RemainingToEmbed;

GO
 
/* -------------------------------------------------------------------------------------

   6. (Optional) Example semantic search - run separately once RemainingToEmbed = 0.

   ------------------------------------------------------------------------------------- */

/*

DECLARE @AOAI_Endpoint SYSNAME = N'<AZURE_OPENAI_ENDPOINT>';

DECLARE @Embedding_Model NVARCHAR(200) = N'<EMBEDDING_MODEL>';

DECLARE @EmbeddingUrl NVARCHAR(4000) = @AOAI_Endpoint + N'/openai/deployments/' + @Embedding_Model + N'/embeddings?api-version=2023-05-15';
 
DECLARE @Query NVARCHAR(4000) = N'medicine used to reduce fever';

DECLARE @QueryPayload NVARCHAR(MAX) = JSON_OBJECT('input': @Query);

DECLARE @QueryResponse NVARCHAR(MAX), @QueryReturnValue INT, @QueryEmbeddingJson NVARCHAR(MAX);
 
EXEC @QueryReturnValue = sp_invoke_external_rest_endpoint

    @url = @EmbeddingUrl,

    @method = 'POST',

    @credential = @AOAI_Endpoint,

    @payload = @QueryPayload,

    @response = @QueryResponse OUTPUT;
 
SET @QueryEmbeddingJson = JSON_QUERY(@QueryResponse, '$.result.data[0].embedding');
 
SELECT TOP (10)

    p.ProductName, e.ContentText,

    1 - VECTOR_DISTANCE('cosine', e.Embedding, CAST(@QueryEmbeddingJson AS VECTOR(1536))) AS Similarity

FROM dbo.ProductDescriptionEmbeddings e

JOIN dbo.ProductCatalog p ON p.ProductID = e.ProductID

ORDER BY VECTOR_DISTANCE('cosine', e.Embedding, CAST(@QueryEmbeddingJson AS VECTOR(1536))) ASC;

*/

 