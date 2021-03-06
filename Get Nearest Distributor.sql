 
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Carl Preusser
-- Create date: 1/16/2017 
-- =============================================
ALTER PROCEDURE [dbo].[GetNearestDistributorTanks]
	-- Add the parameters for the stored procedure here
	 @TestID varchar(50), @TankType Varchar(50), @Capacity Decimal
	 
AS
BEGIN
	 
	SET NOCOUNT ON; 

	CREATE TABLE #TankLocations
	(
	ProductName varchar(120)
   ,ProductId varchar(max) 
   ,CompanyName varchar(80)  
   ,ProductTypeId varchar(max)
   ,DistributorInventoryId varchar(max)
   ,CostPickUp float
   ,CostDelivered float
   ,AttributeName INT
   ,ProductTypeName varchar(max)
	)


	DECLARE @g geography, @Lat Decimal(9,6), @Lon Decimal(9,6) 
	 

	 IF EXISTS (
				 SELECT 1 FROM dbo.Septic_SoilTest test 
				 INNER JOIN dbo.Septic_SoilResidence res ON test.SoilResidenceId = res.Id
				 WHERE test.Id = @TestId AND (test.Latitude Is Not Null AND test.Longitude Is Not Null)
			    )
     
	 BEGIN 
	  
		  SELECT @Lat = Latitude, @Lon = Longitude FROM dbo.Septic_SoilTest test 
				 INNER JOIN dbo.Septic_SoilResidence res ON test.SoilResidenceId = res.Id
				 WHERE test.Id = @TestID
			SET @g = 'POINT(' + Cast(@Lat As varchar) + ' ' + Cast(@Lon As varchar) + ')';

			
							  IF @Lat IS NULL AND @Lon IS NULL
							  
								 BEGIN

							  		SELECT @Lat = c.CentroidLatitude, @Lon = c.CentroidLongitude   FROM  dbo.Septic_SoilTest test 
										 INNER JOIN dbo.Septic_SoilResidence se ON test.SoilResidenceId = se.Id
										 INNER JOIN dbo.Septic_County c ON se.CountyId = c.Id
										 WHERE test.Id = @TestID
									SET @g = 'POINT(' + Cast(@Lat As varchar) + ' ' + Cast(@Lon As varchar) + ')';

								  
								 END 



     END

	 ELSE

	 BEGIN

		SELECT @Lat = c.CentroidLatitude, @Lon = c.CentroidLongitude   FROM  
				  dbo.Septic_SoilTest test  
				 INNER JOIN dbo.Septic_SoilResidence res ON test.SoilResidenceId = res.Id
				 INNER JOIN dbo.Septic_County c ON res.CountyId = c.Id
				  WHERE test.Id = @TestID
			SET @g = 'POINT(' + Cast(@Lat As varchar) + ' ' + Cast(@Lon As varchar) + ')';
	 
	 END;

	 WITH tankLocationsCTE  as
	 (
		SELECT  CAST('POINT(' + Cast(com.Latitude As varchar) + ' ' + Cast(com.Longitude As varchar) + ')' As geography) As SpatialLocation
				,com.CompanyName
				,p.Name As ProductName
				,p.Id As ProductID
				,p.ProductTypeID
				,di.Id As DistributorInventoryID
				,di.CostPickedUp
				,di.CostDelivered
				,CAST(pav.[Name] As Int) As AttributeName
				,pt.ProductTypeName
				 
		 FROM dbo.Septic_ProductTypeAttributeValue ptav
		 INNER JOIN dbo.Septic_Product p ON ptav.ProductID = p.Id
		 INNER JOIN dbo.Septic_DistributorInventory di ON di.ProductID = p.Id
		 INNER JOIN dbo.Septic_Company com ON di.CompanyID = com.Id 
		 LEFT JOIN dbo.Septic_ProductAttributeValue pav ON ptav.AttributeValueID = pav.Id
		 LEFT JOIN dbo.Septic_ProductAttribute pa ON pav.ProductAttributeId = pa.Id 
		 LEFT JOIN dbo.Septic_ProductType pt ON p.ProductTypeID = pt.Id
		 

		 WHERE pa.Name = 'capacity' AND pt.ProductTypeName = @TankType
		 AND 
		 
		 ((case when ISNUMERIC( pav.[Name] ) = 1
						then cast (pav.[Name] as Decimal) 
			  ELSE 5000
			end) 
           >= @Capacity)  
		   ) 


	 INSERT INTO #TankLocations 
	 SELECT   ProductName , ProductID, CompanyName, ProductTypeID, DistributorInventoryID , CostPickedUp, CostDelivered, AttributeName, ProductTypeName
	 FROM tankLocationsCTE  
	 ORDER BY SpatialLocation.STDistance(@g)
	 

	 SELECT * FROM #TankLocations
	 ORDER BY   AttributeName;
	  

	  RETURN
 

	 DROP TABLE #TankLocations

 

END

