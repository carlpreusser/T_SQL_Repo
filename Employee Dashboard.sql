
--#######################################################################
--Created by Carl Preusser
--Example of using functions, creating, updating temporary tables 
--Function CalculateWorkDaysBetweenTwoDates -
--main procedure is EmployeeDashboard_GetEmployeeData


CREATE FUNCTION [dbo].[CalculateWorkDaysBetweenTwoDates] 
	(@DateStarted DATETIME, @DateEnded DATETIME)
RETURNS INT
AS
BEGIN
     
     SET @DateStarted = DATEADD(dd, DATEDIFF(dd, 0, @DateStarted), 0) 
     SET @DateEnded = DATEADD(dd, DATEDIFF(dd, 0, @DateEnded), 0) 
          
     DECLARE @NumberOfWorkDays INT
     SELECT @NumberOfWorkDays = (DATEDIFF(dd, @DateStarted, @DateEnded) + 1)
	               -(DATEDIFF(wk, @DateStarted, @DateEnded) * 2)
   		       -(CASE WHEN DATENAME(dw, @DateStarted) = 'Sunday' THEN 1 ELSE 0 END)
		       -(CASE WHEN DATENAME(dw, @DateEnded) = 'Saturday' THEN 1 ELSE 0 END)
  
     RETURN @NumberOfWorkDays
END
  
-- =============================================
-- Author:		 Carl Preusser
-- Create date: 5-8-17 
-- =============================================
CREATE FUNCTION [dbo].[SearchStartDate]
(
	 
	@EmployeeID INT
)
RETURNS DATE
AS
BEGIN
	
	DECLARE @SearchStartDate Date, @StartDate_12Month Date, @HireDate DATE, @ScheduleStartDate DAte, @ScheduleEndDate Date


	--Fetch current schedule start and end dates
	SET @ScheduleStartDate = (SELECT [DateStarted] FROM tblTimeOffEmp WHERE EmpID = @EmployeeID )
	SET @ScheduleEndDate = (SELECT DateEnded FROM tblTimeOffEmp WHERE EmpID = @EmployeeID )
	 

	
	

	IF @ScheduleEndDate IS NOT NULL AND @ScheduleStartDate is NOT NULL

		BEGIN 
			--So here I am checking if @schedule Start date is greater then 12 months then I will just show 12 months data. 
			SET @StartDate_12Month =(DATEADD(month,-12,GETDATE())-1)
			
			If	@ScheduleStartDate < @StartDate_12Month
				BEGIN 
					SET @SearchStartDate = @StartDate_12Month
				END
			ELSE
				BEGIN
					SET @SearchStartDate = @ScheduleStartDate 
				END	

		END

	ELSE

		BEGIN
	
			SET @StartDate_12Month =(DATEADD(month,-12,GETDATE())-1)
			SET @HireDate = (SELECT HireDte FROM tblTimeOffEmp WHERE EmpID = @EmployeeID )
			
			If	@ScheduleStartDate is Null
				BEGIN

						IF @HireDate > @StartDate_12Month
							BEGIN
								SET @SearchStartDate = @HireDate
							END
						ELSE
							BEGIN	
								SET @SearchStartDate = @StartDate_12Month
							END
				 END
			ELSE
				BEGIN
						IF @HireDate = @ScheduleStartDate

								BEGIN

										IF @HireDate > @StartDate_12Month
											BEGIN
												SET @SearchStartDate = @HireDate
											END
										ELSE
											BEGIN	
												SET @SearchStartDate = @StartDate_12Month
											END 
								END

							ELSE

								BEGIN
					
									SET @SearchStartDate = @ScheduleStartDate

								END
				END
			
		END



	RETURN @SearchStartDate

END


GO



SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[FullMonthsSeparation] 
(
    @DateA DATETIME,
    @DateB DATETIME
)
RETURNS INT
AS
BEGIN
    DECLARE @Result INT

    DECLARE @DateX DATETIME
    DECLARE @DateY DATETIME

    IF(@DateA < @DateB)
    BEGIN
    	SET @DateX = @DateA
    	SET @DateY = @DateB
    END
    ELSE
    BEGIN
    	SET @DateX = @DateB
    	SET @DateY = @DateA
    END

    SET @Result = (
    				SELECT 
    				CASE 
    					WHEN DATEPART(DAY, @DateX) > DATEPART(DAY, @DateY)
    					THEN DATEDIFF(MONTH, @DateX, @DateY) -- - 1
    					ELSE DATEDIFF(MONTH, @DateX, @DateY)
    				END
    				)

    RETURN @Result
END

GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[EmployeeDashboard_GetEmployeeData]

	(
		@EmployeeID int
	)



AS

--This is a script to collect all employee work data for presentation on their dashboard

	IF OBJECT_ID('tempdb..#Temp_Work_Days') IS NOT NULL
    DROP TABLE #Temp_Work_Days;


CREATE TABLE #Temp_Work_Days (
    StartDt DATETIME, 
    EndDt DATETIME,
    Work_Month int,
    Work_Year int,
    WorkDays INT      );
      
    IF OBJECT_ID('tempdb..#Employee_Dashboard_Data') IS NOT NULL
			DROP TABLE #Employee_Dashboard_Data;
			
    IF OBJECT_ID('tempdb..#Temp_Data') IS NOT NULL
			DROP TABLE #Temp_Data;
			
	IF OBJECT_ID('tempdb..#Find_Missing_Months') IS NOT NULL
			DROP TABLE #Find_Missing_Months;
			
	IF OBJECT_ID('tempdb..#Temp_Mileage_Data') IS NOT NULL
			DROP TABLE #Temp_Mileage_Data;
			
	IF OBJECT_ID('tempdb..#Days_Not_Worked') IS NOT NULL
			DROP TABLE #Days_Not_Worked;			
			

DECLARE @EndDate DATETIME
DECLARE @Search_Start_Date as DATETIME
DECLARE @WorkDays INT
DECLARE @Days_Not_Worked VARCHAR(100)
DECLARE @Flex_Employee AS INT
DECLARE @Day_Count INT 

DECLARE @cnt INT = 0;
DECLARE @maxMonth INT 
DECLARE @thisStartDate DATETIME
DECLARE @thisEndDate DATETIME


--determine what date is last
--Schedule StartDate
--Hire Date
--12 months ago from this date...
-----------------------------------------------------------------------------------------------------------------------------
SET @EndDate= CAST(GETDATE() as DATE)
SET @Search_Start_Date=dbo.SearchStartDate(@EmployeeID)

---Initialize
SET @WorkDays=0
SET @Days_Not_Worked = NULL
SET @Flex_Employee=0
SET @Day_Count=0



--Get Employee work days
SELECT  
empID,
CASE WHEN hrsSunday < 1 THEN 'Sunday' else '' END +
 CASE WHEN HrsMonday < 1 THEN ', Monday'  else '' END +
 CASE WHEN HrsTuesday < 1 THEN ', Tuesday' else '' END +
 CASE WHEN HrsWednesday < 1 THEN ', Wednesday' else '' END +
 CASE WHEN HrsThursday < 1 THEN ', Thursday' else '' END +
 CASE WHEN HrsFriday < 1 THEN ', Friday' else '' END +
 CASE WHEN hrsSaturday < 1 THEN ', Saturday' else '' END 
 AS Days_Not_Worked
 ,0 as Day_Count
 ,0 as Flex_Employee
 INTO #Days_Not_Worked
 FROM tbltimeoffEmp
WHERE EmpID=@EmployeeID

-- GET @Day_Count TO DETERMINE FLEX EMPLOYEE

	set @Day_Count = (select 7-(len(Days_Not_Worked) - len(replace(Days_Not_Worked,',',''))+1) from #Days_Not_Worked);

	IF @Day_Count = 5 
		SET @Flex_Employee=0
	ELSE
		SET @Flex_Employee=1

UPDATE #Days_Not_Worked
SET Day_Count=@Day_Count, Flex_Employee=@Flex_Employee
where empID=@EmployeeID

-- Calculate number of Work Days per Month

--SELECT @maxMonth = dbo.FullMonthsSeparation(@Search_Start_Date, GETDATE())  + 1
--Made change in @maxMonth Calculation
--Only add 1 if it is greater than zero. May-9-2017
SELECT @maxMonth = dbo.FullMonthsSeparation(@Search_Start_Date, GETDATE())
--if @maxMonth > 0
--	set @maxMonth = @maxMonth + 1

PRINT 'FLEX_EMPLOYEE'
PRINT @Flex_Employee

IF @Flex_Employee=0
  BEGIN
   
	SET @thisStartDate = @Search_Start_Date
	SET @thisEndDate = EOMONTH(@Search_Start_Date)

	WHILE @cnt <= @maxMonth
	BEGIN
	
	IF @cnt = 0
		BEGIN
			--this is using the real start date...the first iteration
			  SET @thisStartDate =  @thisStartDate --DATEADD(DAY, 1, EOMONTH(@thisStartDate, -1))
			  SET @thisEndDate = EOMONTH(@thisStartDate)

			  -- Logic added if there is only 1 loop 
			  --then set enddate to be @EndDate that is today May-9-2017
			   if  @thisEndDate > @EndDate
				BEGIN 
					SET @thisEndDate = @EndDate
				END


		END
	ELSE IF @Cnt > 0 AND @Cnt <= @maxMonth
		BEGIN
			SET @thisStartDate =  @thisStartDate--DATEADD(DAY, 1, EOMONTH(@thisStartDate, -1))
			SET @thisEndDate = EOMONTH(@thisStartDate)

			if  @thisEndDate > @EndDate
				BEGIN 
					SET @thisEndDate = @EndDate
				END
			
		END 

	 INSERT INTO #Temp_Work_Days (StartDt,EndDt,Work_Month,Work_Year,WorkDays)
			SELECT
				@thisStartDate StartDt
			,@thisEndDate
			,DATEPART(mm,@thisStartDate) AS Work_Month 
			,DATEPART(yyyy,@thisStartDate) AS Work_Year
			,dbo.udf_CalculateNumberOFWorkDays(@thisStartDate,@thisEndDate) WorkDays
		
		SET @cnt = @cnt + 1
		SET @thisStartDate= DATEADD(M,1,( DATEADD(DAY, 1, EOMONTH(@thisStartDate, -1))))
	END
	END
		
ELSE
	
   BEGIN 
   
    SET @thisStartDate = @Search_Start_Date
	SET @thisEndDate = EOMONTH(@Search_Start_Date)

	WHILE @cnt <= @maxMonth
	BEGIN 
	
	IF @cnt = 0
		BEGIN
			--this is using the real start date...the first iteration
			  SET @thisStartDate =  @thisStartDate --DATEADD(DAY, 1, EOMONTH(@thisStartDate, -1))
			  SET @thisEndDate = EOMONTH(@thisStartDate)


		END
	ELSE IF @cnt > 0 AND @cnt <= @maxMonth
		BEGIN
			SET @thisStartDate =  @thisStartDate--DATEADD(DAY, 1, EOMONTH(@thisStartDate, -1))
			SET @thisEndDate = EOMONTH(@thisStartDate) 

			if  @thisEndDate > @EndDate
				BEGIN 
					SET @thisEndDate = @EndDate 
				END
		END 
		
     INSERT INTO #Temp_Work_Days (StartDt,EndDt,Work_Month,Work_Year,WorkDays)
 
		 SELECT
		 @thisStartDate StartDt
		,@thisEndDate
		,DATEPART(mm,@thisStartDate) AS Work_Month 
		,DATEPART(yyyy,@thisStartDate) AS Work_Year
		,dbo.udf_GetFlexWorkDays(@thisStartDate,@thisEndDate, Days_Not_Worked) WorkDays
		FROM #Days_Not_Worked 

		  SET @cnt = @cnt + 1
		  SET @thisStartDate= DATEADD(M,1,( DATEADD(DAY, 1, EOMONTH(@thisStartDate, -1))))
	 END

	
 END 

 --Added May - 9- 2017
 --If no daily created between start day and end date then record is not showing on dashboard
 --If that is the case then check from 3 days back.
DECLARE @Search_Start_Date_Temp DateTime
if	exists(select 1 from  [DBO].[DAILIES] where EMPLOYEEID = @EMPLOYEEID  AND DAILYDATE BETWEEN @SEARCH_START_DATE AND @ENDDATE)
	BEGIN
		set @Search_Start_Date_Temp = @Search_Start_Date
	END
ELSE
	BEGIN
		set @Search_Start_Date_Temp = DateAdd(D,-3,@Search_Start_Date)
	END

SELECT 
dly.EmployeeID
,et.HireDte HireDate
, DailyStatusID
, DATEPART(mm,DailyDate) AS Daily_Month 
,DATEPART(yyyy,DailyDate) AS Daily_Year
, COUNT(*) DailyCount
, (CASE WHEN  et.HireDte between @Search_Start_Date and @EndDate THEN 1 ELSE 0 END) as NewHire
  INTO  #Temp_Data
  FROM [CCBHEnterprise].[dbo].[Dailies] dly 
  LEFT Join [CCBHEnterprise].[dbo].[tbltimeoffEmp] et on et.EmpID=dly.EmployeeID
  LEFT JOIN #Temp_Work_Days wd on DATEPART(mm,DailyDate)=Work_Month and DATEPART(yyyy,DailyDate)=Work_Year
  WHERE dly.EmployeeID = @EmployeeID and DailyDate between @Search_Start_Date_Temp and @EndDate
  group by dly.EmployeeID
  ,et.HireDte
  ,DATEPART(yyyy,DailyDate)
  ,DATEPART(mm,DailyDate),DailyStatusID,Work_Month,Work_Year
  HAVING DATEPART(mm,DailyDate) =Work_Month and DATEPART(yyyy,DailyDate)=Work_Year
   
 
SELECT DISTINCT EmployeeId Employee_ID
, Daily_Month Work_Month
, Daily_Year  Work_Year
, Dailies_Approved = 0
, Dailies_Submitted= 0
, Dailies_Incomplete = 0
, Mileage_Approved = 0
, Mileage_Submitted= 0
, Mileage_Incomplete = 0
INTO #Employee_Dashboard_Data 
FROM #Temp_Data 

-- Update Approved Daily Count 
UPDATE #Employee_Dashboard_Data 
SET
	Dailies_Approved=td.DailyCount
FROM 
	#Employee_Dashboard_Data 
INNER JOIN 
	#Temp_Data td 
ON td.EmployeeID=Employee_ID and td.Daily_Year=Work_Year and 
					td.Daily_Month= Work_Month 
WHERE DailyStatusID=2

-- Update Submitted Daily Count

UPDATE #Employee_Dashboard_Data 
SET
	Dailies_Submitted=td.DailyCount
FROM 
	#Employee_Dashboard_Data 
INNER JOIN 
	#Temp_Data td 
ON td.EmployeeID=Employee_ID and td.Daily_Year=Work_Year and 
					td.Daily_Month= Work_Month 
WHERE DailyStatusID=3  

-- Update Incomplete Daily Count

UPDATE #Employee_Dashboard_Data 
SET
	Dailies_Incomplete=(CASE WHEN(wd.WorkDays-(Dailies_Approved + Dailies_Submitted))>0 THEN (wd.WorkDays-(Dailies_Approved + Dailies_Submitted)) ELSE 0 END)
FROM 
	#Employee_Dashboard_Data dd
INNER JOIN 
	#Temp_Work_Days wd
ON dd.Work_Year=wd.Work_Year and dd.Work_Month =wd.Work_Month 

 

-- INSERT missing Months into #Employee_Dashboard_Data 
select distinct 
dd.Employee_ID,wd.Work_Month,wd.Work_Year,td.HireDate,td.NewHire 
INTO #Find_Missing_Months
from #Employee_Dashboard_Data dd
cross join #Temp_Work_Days wd
left join #Temp_Data td on td.EmployeeID=dd.Employee_ID
order by dd.Employee_ID,wd.Work_Year,wd.Work_Month

INSERT INTO #Employee_Dashboard_Data (Employee_ID,Work_Month,Work_Year,
	Dailies_Approved,Dailies_Submitted,Dailies_Incomplete
	,Mileage_Approved,Mileage_Submitted,Mileage_Incomplete )
SELECT fm.Employee_ID Employee_ID
	,fm.Work_Month Work_Month
	,fm.Work_Year Work_Year
	,0 Dailies_Approved
	,0 Dailies_Submitted
	,wd.WorkDays Dailies_Incomplete 
	,0 Mileage_Approved
	,0 Mileage_Submitted
	,0 Mileage_Incomplete 
FROM #Find_Missing_Months fm
	Left JOIN #Employee_Dashboard_Data dd
ON fm.Employee_ID=dd.Employee_ID and fm.Work_Year=dd.Work_Year and fm.Work_Month =dd.Work_Month
	left join #Temp_Work_Days wd
ON fm.Work_Year=wd.Work_Year and fm.Work_Month =wd.Work_Month
-- change made 3/14/2016 DM, problem reading employees daily potentially fixed
where dd.employee_id is null and convert(varchar(7),cast((cast(fm.Work_Month as CHAR(2)) + '/01/' + cast(fm.Work_Year as CHAR(4))) as date ),111) >= convert(varchar(7),fm.HireDate,111) 
order by fm.Employee_ID,fm.Work_Year, fm.Work_Month

--Recalculate Hire Month Daily Incomplete Data 
IF @Flex_Employee=0
	UPDATE #Employee_Dashboard_Data 
	SET
	 
		--Change made to get correct incomplete dailies for new employees
		Dailies_Incomplete=(CASE WHEN(select dbo.udf_CalculateNumberOFWorkDays(td.HireDate,DATEADD(d, -1, DATEADD(m, DATEDIFF(m, 0, td.HireDate) + 1, 0)))
		-(Dailies_Approved + Dailies_Submitted))>0 THEN 
			 (select dbo.udf_CalculateNumberOFWorkDays(td.HireDate,DATEADD(d, -1, DATEADD(m, DATEDIFF(m, 0, td.HireDate) + 1, 0)))-(Dailies_Approved + Dailies_Submitted)) ELSE 0 END)
	FROM 
		#Employee_Dashboard_Data dd
	INNER JOIN 
		#Temp_Data td
	ON dd.Employee_ID= td.EmployeeID and Work_Year=DATEPART(yyyy,td.HireDate) and dd.Work_Month =DATEPART(mm,td.HireDate)
  
 ELSE
	UPDATE #Employee_Dashboard_Data 
	SET

		Dailies_Incomplete=(CASE WHEN(select dbo.udf_GetFlexWorkDays(td.HireDate,DATEADD(d, -1, DATEADD(m, DATEDIFF(m, 0, td.HireDate) + 1, 0)),Days_Not_Worked)
	 -(Dailies_Approved + Dailies_Submitted))>0 THEN
		 (select dbo.udf_GetFlexWorkDays(td.HireDate,DATEADD(d, -1, DATEADD(m, DATEDIFF(m, 0, td.HireDate) + 1, 0)),Days_Not_Worked)-(Dailies_Approved + Dailies_Submitted)) ELSE 0 END)
	FROM 
		#Employee_Dashboard_Data dd
	INNER JOIN 
		#Temp_Data td
	ON dd.Employee_ID= td.EmployeeID and Work_Year=DATEPART(yyyy,td.HireDate) and dd.Work_Month =DATEPART(mm,td.HireDate)
	LEFT JOIN #Days_Not_Worked ON dd.Employee_ID=EmpID
	

--UPDATE MILEAGE DATA 
select  m.EmployeeID,DATEPART(yyyy,m.TravelDate) Travel_Year,DATEPART(mm,m.TravelDate) Travel_Month, m.MileageStatusID,COUNT(*) Total_Mileage
 INTO #Temp_Mileage_Data
 from Mileages m
 inner join #Employee_Dashboard_Data dd
 on m.EmployeeID=dd.Employee_ID and DATEPART(yyyy,m.TravelDate)=dd.Work_Year and DATEPART(mm,m.TravelDate)=dd.Work_Month
 group by dd.Employee_ID,dd.Work_Month,dd.Work_Year,m.EmployeeID, DATEPART(yyyy,m.TravelDate),DATEPART(mm,m.TravelDate), m.MileageStatusID


-- Update Approved Mileage Count 
UPDATE #Employee_Dashboard_Data 
SET
	Mileage_Approved=td.Total_Mileage
FROM 
	#Employee_Dashboard_Data 
INNER JOIN 
	#Temp_Mileage_Data td 
ON td.EmployeeID=Employee_ID and td.Travel_Year=Work_Year and 
					td.Travel_Month= Work_Month 
WHERE  MileageStatusID=4 

-- Update Submitted Mileage Count 
UPDATE #Employee_Dashboard_Data 
SET
	Mileage_Submitted=td.Total_Mileage
FROM 
	#Employee_Dashboard_Data 
INNER JOIN 
	#Temp_Mileage_Data td 
ON td.EmployeeID=Employee_ID and td.Travel_Year=Work_Year and 
					td.Travel_Month= Work_Month 
WHERE  MileageStatusID=5

-- Update Incomplete Mileage Count 
UPDATE dd
SET
	dd.Mileage_Incomplete=Incomplete
FROM #Employee_Dashboard_Data  dd INNER JOIN
	(Select dd.Employee_ID,dd.Work_Year,dd.Work_Month,SUM(td.Total_Mileage) as Incomplete
	 from #Employee_Dashboard_Data dd
		join #Temp_Mileage_Data td 
		ON dd.Employee_ID=td.EmployeeID and dd.Work_Year=td.Travel_Year and 
					dd.Work_Month =td.Travel_Month 
group by dd.Employee_ID,dd.Work_Year,dd.Work_Month,td.MileageStatusID
HAVING  td.MileageStatusID NOT IN (4,5)) ij 
	on ij.Employee_ID=dd.Employee_ID and ij.Work_Year=dd.Work_Year and ij.Work_Month=dd.Work_Month
	
SELECT DISTINCT dd.Employee_ID EmployeeId
		, e.LastName+', '+e.FirstName as EmployeeName
		, hrsSunday
		,CONVERT(varchar(15),CAST([StartTimeSunday] AS TIME),100)As [StartTimeSunday]
		,CONVERT(varchar(15),CAST([EndTimeSunday] AS TIME),100)As [EndTimeSunday]
		,[HrsMonday]
       ,CONVERT(varchar(15),CAST([StartTimeMonday] AS TIME),100)As [StartTimeMonday]
       ,CONVERT(varchar(15),CAST([EndTimeMonday] AS TIME),100)As [EndTimeMonday]
       ,[HrsTuesday]
       ,CONVERT(varchar(15),CAST([StartTimeTuesday] AS TIME),100)As [StartTimeTuesday]
       ,CONVERT(varchar(15),CAST([EndTimeTuesday] AS TIME),100)As [EndTimeTuesday]
       ,[HrsWednesday]
       ,CONVERT(varchar(15),CAST([StartTimeWednesday] AS TIME),100)As [StartTimeWednesday]
       ,CONVERT(varchar(15),CAST([EndTimeWednesday] AS TIME),100)As [EndTimeWednesday]
       ,[HrsThursday]
       ,CONVERT(varchar(15),CAST([StartTimeThursday] AS TIME),100) As [StartTimeThursday]
       ,CONVERT(varchar(15),CAST([EndTimeThursday] AS TIME),100)As [EndTimeThursday]
       ,[HrsFriday]
       ,CONVERT(varchar(15),CAST([StartTimeFriday] AS TIME),100)As [StartTimeFriday]
       ,CONVERT(varchar(15),CAST([EndTimeFriday] AS TIME),100)As [EndTimeFriday]
       ,[hrsSaturday]
       ,CONVERT(varchar(15),CAST([StartTimeSaturday] AS TIME),100)As [StartTimeSaturday]
       ,CONVERT(varchar(15),CAST([EndTimeSaturday] AS TIME),100)As [EndTimeSaturday]
 FROM #Employee_Dashboard_Data dd
 left join Employees  e on dd.Employee_ID=e.EmployeeID
 LEFT JOIN [CCBHEnterprise].[dbo].[tbltimeoffEmp] on e.EmployeeID=EmpID
 order by EmployeeName
	
	
SELECT dd.Employee_ID EmployeeId
, dd.Work_Year
, dd.Work_Month
, dd.Dailies_Approved
, dd.Dailies_Submitted
, dd.Dailies_Incomplete
, dd.Mileage_Approved
, dd.Mileage_Submitted
, dd.Mileage_Incomplete
 FROM #Employee_Dashboard_Data dd
 WHERE  (dd.Dailies_Submitted+dd.Dailies_Incomplete+dd.Mileage_Submitted+dd.Mileage_Incomplete) > 0
 order by EmployeeId,dd.Work_Year,dd.Work_Month
 
 -- Get Count of TimeOff to be Approved 
select distinct tod.empID,COUNT(*) NeedsApproval
FROM dbo.tblTimeOff tod
where exists (select distinct dd.Employee_ID from #Employee_Dashboard_Data dd where tod.empID=dd.Employee_ID )
	and  tod.Status='Submitted' 
group by tod.empID
order by tod.empID

--GET Count of Overtime to be Approved (Pre-Approval) 
	Select  EmpID as empID
	,COUNT(*) As RequestCount
	from tblTimeOffApproveOT
	where Status='Requested' and EmpID=@EmployeeID	
	GROUP BY empID

	
-- GET Count of Overtime Requests with no Approval 
  SELECT o.empID , COUNT(*) as RequestCount
  FROM [CCBHEnterprise].[dbo].[tblOvertime] as o
  left join [CCBHEnterprise].[dbo].[tblTimeOffApproveOT] as a 
  on o.empID = a.empid and o.[TimeOffDate]=a.[WorkDate]
  WHERE o.empID = @EmployeeID and o.Status = 'Requested' and a.PreApproveID is null
  GROUP BY o.empID

   