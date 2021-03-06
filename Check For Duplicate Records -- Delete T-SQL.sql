 
-- One way to check for Duplicate Records
SELECT 
        [Id] 
       [CompanyId] 
      ,[LastName]
      
  FROM [dbo].[Septic_CompanyEmployee]

  WHERE Id IN 
(
	SELECT Id
	FROM 
	(
		SELECT ROW_NUMBER() OVER (PARTITION BY  [LastName] 
					ORDER BY [LastName]) rank 
		FROM [dbo].[Septic_CompanyEmployee]  
	) a
	WHERE a.rank > 1
)
ORDER BY LastName

 
BEGIN TRAN ; 
 
WITH duplicateLastName As
(
SELECT LastName, Count(*) As RecordCnt
FROM dbo.Septic_CompanyEmployee
GROUP BY LastName
HAVING Count(*) > 1
)
,extraDuplicateRecordForDeletion As (
SELECT
  Id
 ,LastName
 ,ROW_NUMBER() OVER (PARTITION BY  [LastName] 
					ORDER BY [LastName])  As RowNum
FROM 
dbo.Septic_CompanyEmployee ce 
WHERE LastName IN (SELECT LastName FROM duplicateLastName) 
)

--SELECT Id FROM extraDuplicateRecordForDeletion WHERE RowNum > 1
DELETE FROM dbo.Septic_CompanyEmployee WHERE Id IN (SELECT Id FROM extraDuplicateRecordForDeletion WHERE RowNum > 1)

--COMMIT TRAN
