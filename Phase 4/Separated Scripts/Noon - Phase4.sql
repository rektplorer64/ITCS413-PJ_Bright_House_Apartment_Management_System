USE BRIGHT_HOUSE
GO

/**
 *  -- 4: Insert the details of a new Room in a Branch
 */
CREATE PROCEDURE spInsertNewRoom(
    @roomBranchNumber     int,
    @roomNumber           int,
    @roomSize             char(3)
)
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @roomFloor int
    SET @roomFloor = LEFT(@roomNumber, 1)

    -- Insert the given room information into the Room Table
    INSERT INTO Room VALUES (@roomBranchNumber, @roomNumber, @roomSize, @roomFloor)

    -- Display the result
    SELECT * FROM Room WHERE roomBranchNumber = @roomBranchNumber AND roomNumber = @roomNumber
END
GO;

EXEC spInsertNewRoom 1, 601, 'SUP'
GO



/**
 * -- 5: Insert the details of a new Customer Payment Billing line
 *
 * This method defines a way for other procedures to add/insert a new billing line.
 */
CREATE PROCEDURE spInsertCustomerPaymentBillingLine(
    @targetBillingNum int,
    @lineName varchar(40),
    @lineAmount decimal(19, 4),
    @lineStatus varchar(10),
    @lineDiscountAmount decimal(19,4),
    @lineRecorderEmployeeNum int,
    @outputBillingNum int OUTPUT,
    @outputBillingLineNum int OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON

    -- Get the latest Billing Line Associated with the billing number
    DECLARE @targetBillingLineTable table(targetBillingLineNum int)
    INSERT @targetBillingLineTable EXEC spGetLatestBillingLineByBillingNum @targetBillingNum

    -- Get the last billing line of the the given target billing number
    DECLARE @targetBillingLine int
    SELECT @targetBillingLine = targetBillingLineNum FROM @targetBillingLineTable

    -- Sometimes the @targetBillingLine may already equal to ONE
    IF NOT @targetBillingLine = 1
        SET @targetBillingLine = @targetBillingLine + 1

    -- If we cannot find the last billing line, it means that it is not exist.
    IF @targetBillingLine IS NULL
        THROW 50001, 'Sorry, we cannot insert a new Billing Line because we cannot find a BillingLine number within the rental period.', 1

    -- Current Time
    DECLARE @currentTime datetime = CURRENT_TIMESTAMP

    -- Insert a billing line into the associated main bill
    INSERT INTO CustomerBillingLine
    VALUES (@targetBillingNum, @targetBillingLine, @lineName, @lineAmount, @lineStatus, @currentTime,
            @lineDiscountAmount, @lineRecorderEmployeeNum, @currentTime)

    -- The Query returns some value
    SELECT @outputBillingNum = customerBillingNumber, @outputBillingLineNum = customerBillingLineNumber
    FROM CustomerBillingLine
    WHERE customerBillingNumber = @targetBillingNum AND customerBillingLineNumber = @targetBillingLine

    -- Select the newly inserted item.
    SELECT *
    FROM CustomerBillingLine
    WHERE customerBillingNumber = @targetBillingNum AND customerBillingLineNumber = @targetBillingLine
END
GO;




/**
 * -- 20: Identify the average salary of employees in each position, gender, branch.
 */
CREATE VIEW EmployeePositionSalaryView AS
SELECT Roles.employeeNum,
       employeeFullName,
       employeeGender,
       employeeAge,
       branchNumber,
       branchName,
       Roles.employeeRole,
       dailyWage,
       AVG(workingShiftLengthHour) AS avgWorkingHour
FROM (
     SELECT employeeNum,
            dbo.funFormatFullNameString(employeeFirstName, employeeMiddleName, employeeLastName)
                AS employeeFullName,
            dbo.funCalculateAge(employeeDOB, current_timestamp)
                AS employeeAge,
            branchNumber,
            branchName,
            dailyWage,
            employeeGender
     FROM Employee
         LEFT JOIN Branch B2 ON Employee.employeeBranchNumber = B2.branchNumber) Details
         LEFT JOIN (
              SELECT employeeNum,
                     managerNum,
                     accountantNum,
                     cleaningPersonnelNum,
                     COALESCE(
                             IIF(managerNum IS NOT NULL, 'Manager', NULL),
                             IIF(accountantNum IS NOT NULL, 'Accountant', NULL),
                             IIF(cleaningPersonnelNum IS NOT NULL, 'Cleaning Personnel', NULL),
                             'Security'
                         ) AS employeeRole
              FROM (
                   SELECT employeeNum
                   FROM Employee) X
                       LEFT JOIN Manager M ON X.employeeNum = M.managerNum
                       LEFT JOIN Accountant A ON X.employeeNum = A.accountantNum
                       LEFT JOIN CleaningPersonnel CP ON X.employeeNum = CP.cleaningPersonnelNum
) Roles ON Roles.employeeNum = Details.employeeNum
         LEFT JOIN EmployeeWorkingShift EWS ON workingShiftEmployeeNum = Roles.employeeNum
GROUP BY Roles.employeeNum, employeeFullName, employeeAge, branchNumber, branchName, employeeRole, dailyWage,
         employeeGender
GO;

-- List all employees with respects to their role, daily wage, and average working hours.
SELECT * FROM EmployeePositionSalaryView
GO;




/**
 * -- 21: Identify the total employee payroll for day, week or month.
 */
CREATE VIEW EmployeePayrollView AS
SELECT employeeNum,
       employeeBranchNumber AS branchNumber,
       dbo.funFormatFullNameString(employeeFirstName, employeeMiddleName, employeeLastName) AS employeeFullName,
       dailyWage, financialTransactionAmount, financialTransactionTime
FROM Employee E
    JOIN EmployeeWagePayment EWP ON E.employeeNum = EWP.wagePaymentEmployeeNum
    JOIN FinancialTransaction FT ON EWP.wagePaymentFinancialTransactionNumber = FT.financialTransactionNumber;

-- List the transactions to employees of branch #1 with the fifteenth week of 2019
SELECT *
FROM EmployeePayrollView
WHERE branchNumber = 1 AND DATEPART(WEEK, financialTransactionTime) = 15
  AND DATEPART(YEAR, financialTransactionTime) = 2019
GO;



/**
 * -- 22: Identify customer information as well as his/her first rental branch.
 *
 * This view also identifies the ongoing rental of each customer.
 * Ongoing, in this case, means the rental that is active based on the fact that the current timestamp,
 * is within the a rental period.
 *
 * Moreover, it will also identifies the last rental of each customer.
 */
CREATE VIEW CustomerView AS
SELECT CX.customerNum,
       dbo.funFormatFullNameString(customerFirstName, customerMiddleName, customerLastName) AS fullName,
       customerNickName AS nickname,
       dbo.funCalculateAge(customerDOB, CURRENT_TIMESTAMP)                                  AS age,
       customerGender                                                                       AS gender,
       customerProfession                                                                   AS profession,
       customerNationality                                                                  AS nationality,
       customerEmail                                                                        AS email,
       R.rentalBranchNumber                                                                 AS firstRentalBranch,
       firstRentalNumber,
       lastRentalNumber,
       lastRentalEndingTime,
       lastRentalBranch,
       Rp.rentalBranchNumber                                                                AS ongoingRentalBranch,
       ongoingRentalPeriod
FROM Customer CX
         LEFT JOIN (
              -- Get the first rental of each customer
              SELECT customerNum, MIN(rentalNumber) AS firstRentalNumber
              FROM Rental
                       JOIN RentalCustomer RC ON Rental.rentalNumber = RC.rentalCustomerRentalNumber
                       JOIN Customer C ON RC.rentalCustomerNum = C.customerNum
              GROUP BY customerNum) A ON A.customerNum = CX.customerNum
         LEFT JOIN Rental R ON R.rentalNumber = A.firstRentalNumber
         LEFT JOIN (
                   SELECT DISTINCT rentalPeriodRentalNumber AS ongoingRentalPeriod, rentalBranchNumber
                   FROM RentalPeriod
                            JOIN Rental R2 ON RentalPeriod.rentalPeriodRentalNumber = R2.rentalNumber
                   WHERE CURRENT_TIMESTAMP BETWEEN rentalPeriodStartingTime AND rentalPeriodEndingTime) RP
                   ON R.rentalNumber = RP.ongoingRentalPeriod
         LEFT JOIN (
                   SELECT --RC.rentalCustomerNum,
                       DISTINCT
                          FIRST_VALUE(rentalCustomerNum)
                                      OVER (PARTITION BY rentalCustomerNum ORDER BY rentalPeriodEndingTime DESC) AS rentalCustomerNum,
                          FIRST_VALUE(rentalNumber)
                                      OVER (PARTITION BY rentalCustomerNum ORDER BY rentalPeriodEndingTime DESC) AS lastRentalNumber,
                          FIRST_VALUE(rentalPeriodEndingTime)
                                      OVER (PARTITION BY rentalCustomerNum ORDER BY rentalPeriodEndingTime DESC) AS lastRentalEndingTime,
                          FIRST_VALUE(rentalBranchNumber)
                                      OVER (PARTITION BY rentalCustomerNum ORDER BY rentalPeriodEndingTime DESC) AS lastRentalBranch
                   FROM RentalCustomer RC
                            JOIN Rental R2 ON RC.rentalCustomerRentalNumber = R2.rentalNumber
                            JOIN RentalPeriod RP ON R2.rentalNumber = RP.rentalPeriodRentalNumber
) LV ON A.customerNum = LV.rentalCustomerNum

-- List customers who lastly stayed at the branch #10
SELECT * FROM CustomerView WHERE lastRentalBranch = 10

-- List customers who had stayed and checked out with either in branch #1, #2 or #3 within the last 4 months
SELECT *
FROM CustomerView
WHERE lastRentalBranch in (1, 2, 3) AND lastRentalEndingTime
    BETWEEN DATEADD(MONTH, -4, CURRENT_TIMESTAMP) AND CURRENT_TIMESTAMP
ORDER BY lastRentalEndingTime DESC


-- SELECT * FROM RentalCustomer WHERE rentalCustomerNum = 256

-- 23: is combined with Number 32
-- CREATE VIEW customerNationalityView AS
--     SELECT customerNum, customerNationality, GETDATE() - customerDOB AS customerAge
--     FROM Customer
--
-- EXEC customerNationalityView
-- GO



-- 24: is combined with Number 22
-- CREATE VIEW BranchCustomerView AS


-- 25: Combined with Number 22
-- CREATE PROCEDURE lastVisitedCustomer(@duration DATE)
--     AS
--     BEGIN
--         SET NOCOUNT ON
--         SELECT customerNum, customerFirstName, customerLastName, customerNickName, rentalCustomerRentalNumber, rentalRoomNumber,
--                rentalStartingTime, rentalEndingTime
--         FROM Customer, Rental, RentalCustomer
--         WHERE @duration BETWEEN (SELECT rentalStartingTime FROM Rental) AND (SELECT rentalEndingTime FROM Rental)
--     END
-- GO;
-- EXEC lastVisitedCustomer
-- GO




/**
 * -- 26: For each Customer, List their rentals that are within the given time window.
 *
 * This will return customer number as well as the number of days since they stayed,
 * aggregated string of recent rentals and also the count of rental rentals.
 */
CREATE PROCEDURE spListCustomerRentalsByTimeWindow(
    @timeRangeStart datetime,
    @timeRangeEnd   datetime
) AS
BEGIN
    SET NOCOUNT ON

    -- If the given beginning of the time range is not given, set it to the current time.
    IF @timeRangeEnd IS NULL
        SET @timeRangeEnd = CURRENT_TIMESTAMP

    -- If the given ending of the time range is not given set it to the next 3 months.
    IF @timeRangeStart IS NULL
        SET @timeRangeStart = DATEADD(MONTH , -6, @timeRangeEnd)

    IF @timeRangeStart > @timeRangeEnd
        THROW 50001, 'The beginning of the time range is greater than the end of the time range!', 1


    SELECT A.customerNum, sinceDaysAgo, recentRentals, recentRentalCount
    FROM (
         SELECT customerNum, DATEDIFF(DAY, lastRentalEndingTime, @timeRangeEnd) AS sinceDaysAgo
          FROM CustomerView
          WHERE lastRentalEndingTime BETWEEN @timeRangeStart AND @timeRangeEnd
     ) A JOIN (
         SELECT customerNum, STRING_AGG(rentalNumber, ';') AS recentRentals, COUNT(DISTINCT rentalNumber) AS recentRentalCount
    FROM (
          SELECT DISTINCT customerNum, rentalNumber, rentalEndingTime
          FROM Customer
                   JOIN RentalCustomer RC ON Customer.customerNum = RC.rentalCustomerNum
                   JOIN Rental R2 ON RC.rentalCustomerRentalNumber = R2.rentalNumber
                   JOIN RentalPeriod RP ON R2.rentalNumber = RP.rentalPeriodRentalNumber
          WHERE (rentalStartingTime <= @timeRangeEnd)
            AND (rentalEndingTime >= @timeRangeStart)) X
    GROUP BY customerNum
        ) B
    ON A.customerNum = B.customerNum

END
GO;

EXEC spListCustomerRentalsByTimeWindow NULL, NULL;


/**
 * -- 27: List the details of each type of supply for each branch
 *
 * The SummarySupplyView lists details of each supply for each branch.
 * Each entry will display amountOnHand.
 */
CREATE VIEW SummarySupplyView AS
SELECT branchNumber,
       totalEntries,
       quantityTransferred,
       (returningQuantity + purchasingQuantity) - withdrawQuantity AS amountOnHand,
       X.supplyNumber,
       supplyName,
       supplyType,
       supplyUnitPrice,
       supplyCategory,
       supplyReturningMinuteTimeWindow
FROM (
         SELECT branchNumber,
                supplyNumber,
                COUNT(entryNumber)      AS totalEntries,
                SUM(supplyUnitQuantity) AS quantityTransferred
         FROM Branch
                  JOIN InventoryEntry ON Branch.branchNumber = InventoryEntry.entryBranchNumber
                  JOIN Supply S ON InventoryEntry.entrySupplyNumber = S.supplyNumber
         GROUP BY branchNumber, supplyNumber
     ) A JOIN (
          SELECT supplyNumber,
                 supplyName,
                 supplyType,
                 supplyUnitPrice,
                 supplyCategory,
                 supplyReturningMinuteTimeWindow
          FROM Supply S
                   LEFT JOIN ReturningSupply RS ON supplyNumber = RS.returningSupplyNumber
    ) X ON A.supplyNumber = X.supplyNumber
    JOIN (
        SELECT S.supplyNumber, Withdrawing.count withdrawQuantity,
               Purchasing.count purchasingQuantity,
               Returning.count returningQuantity
        FROM Supply S
            JOIN (SELECT entrySupplyNumber, SUM(supplyUnitQuantity) count FROM InventoryEntry WHERE inventoryEntryType = 'W' GROUP BY entrySupplyNumber) Withdrawing
                ON S.supplyNumber = Withdrawing.entrySupplyNumber
            JOIN (SELECT entrySupplyNumber, SUM(supplyUnitQuantity) count FROM InventoryEntry WHERE inventoryEntryType = 'P' GROUP BY entrySupplyNumber) Purchasing
                ON S.supplyNumber = Purchasing.entrySupplyNumber
            JOIN (SELECT entrySupplyNumber, SUM(supplyUnitQuantity) count FROM InventoryEntry WHERE inventoryEntryType = 'R' GROUP BY entrySupplyNumber) Returning
                ON S.supplyNumber = Returning.entrySupplyNumber
    ) K ON X.supplyNumber = K.supplyNumber

-- Shows the summary of all supply types for the first branch
SELECT * FROM SummarySupplyView WHERE branchNumber = 1 ORDER BY supplyNumber


/**
 * -- 28: Show the summary of supply weekly usage in each branch
 */
CREATE VIEW WeeklySupplySummaryView AS
    SELECT entryBranchNumber, supplyNumber, supplyName, supplyCategory,
           DATEPART(WEEK, overseeingTimestamp) AS weekOfYear,
           DATEPART(YEAR, overseeingTimestamp) AS year,
           SUM(supplyUnitQuantity) AS totalQuantityUsed
    FROM Supply JOIN InventoryEntry
    ON Supply.supplyNumber = InventoryEntry.entrySupplyNumber
    WHERE inventoryEntryType = 'W'
    GROUP BY entryBranchNumber, supplyNumber, overseeingTimestamp, supplyName, supplyCategory

-- Shows the usage of each supply type of the first branch at the fifteenth week of 2019
SELECT * FROM WeeklySupplySummaryView WHERE entryBranchNumber = 1 AND weekOfYear = 15 AND year = 2019 ORDER BY totalQuantityUsed DESC



/**
 * -- 29: List every room in all branches as well as identify its occupation or reservation status
 *
 * List room details with a status of rental by a given branch or area.
 * List all rooms that currently has guests staying grouped by room size.
 */
CREATE VIEW RoomRentalStatusView AS
SELECT XR.roomBranchNumber AS branchNumber,
       B2.branchName,
       B2.branchProvince,
       B2.branchDistrict,
       dbo.funFormatFullRoomNumberString(XR.roomBranchNumber, XR.roomNumber) AS roomNumber,
       XR.roomFloor,
       XR.roomSize,
       IIF(A.roomNumber IS NULL, 'Free', 'Occupied')                         AS isOccupied,
       IIF(B.roomNumber IS NULL, 'Not Reserved', 'Reserved')                 AS isReserved
FROM Room XR
         LEFT JOIN (
                   SELECT roomBranchNumber, roomNumber
                   FROM Room R
                        -- If the room does exist in the list of ongoing rental
                   WHERE EXISTS(SELECT *
                                FROM Rental
                                         JOIN (
                                              SELECT *
                                              FROM Room
                                              WHERE roomNumber = R.roomNumber
                                                AND roomBranchNumber = R.roomBranchNumber) R2
                                              ON rentalRoomNumber = R2.roomNumber
                                     -- Where the rental is overlapping with the given time range
                                WHERE CURRENT_TIMESTAMP BETWEEN rentalStartingTime AND rentalEndingTime)
) A ON A.roomBranchNumber = XR.roomBranchNumber AND A.roomNumber = XR.roomNumber
         LEFT JOIN
     (-- If the room does exist in the list of pending reservation
     SELECT roomBranchNumber, roomNumber
     FROM Room R
     WHERE EXISTS(SELECT *
                  FROM Reservation
                           JOIN ReservedRoom
                                ON Reservation.reservationNumber = ReservedRoom.reservedRoomReservationNumber
                           JOIN (
                                SELECT *
                                FROM Room
                                WHERE roomNumber = R.roomNumber
                                  AND roomBranchNumber = R.roomBranchNumber) R2
                                ON reservedRoomNumber = R2.roomNumber
                       -- When the expected reservation time range is overlapping with the given time range
                  WHERE CURRENT_TIMESTAMP BETWEEN expectedCheckInDate AND expectedCheckOutDate)) B
     ON B.roomBranchNumber = XR.roomBranchNumber AND B.roomNumber = XR.roomNumber
JOIN Branch B2 ON XR.roomBranchNumber = B2.branchNumber

-- Retrieve the list of rooms that are not occupied and not reserved in branch #1
SELECT * FROM RoomRentalStatusView WHERE branchNumber = 1 AND isOccupied = 'Free' AND isReserved = 'Not Reserved' ORDER BY roomNumber;




/**
 * -- 30: List every room in all branches as well as identify its occupation or reservation status
 *
 * List room details with a status of rental by a given branch or area.
 * List all rooms that currently has guests staying grouped by room size.
 */
CREATE VIEW TopTenMonthlyBranchCustomerTransaction AS
SELECT ranking,
       transacNumber,
       amount as transacAmount,
       customerNum,
       customerFullName,
       customerNationality,
       month,
       year,
       branchNumber
FROM (
     SELECT transacNumber,
            month,
            year,
            rentalBranchNumber                                                                   AS branchNumber,
            customerNum,
            dbo.funFormatFullNameString(customerFirstName, customerMiddleName, customerLastName) AS customerFullName,
            customerNationality,
            amount,
            -- Ranks each transaction based on its Branch/Month/Year group
            row_number() OVER (PARTITION BY rentalBranchNumber,month,year ORDER BY amount DESC) AS ranking
     FROM CustomerBilling CB
              JOIN Rental R ON CB.billingRentalNumber = R.rentalNumber
              JOIN Customer C ON CB.billingCustomerNum = C.customerNum
              LEFT JOIN (
                        SELECT financialTransactionNumber      AS transacNumber,
                               MONTH(financialTransactionTime) AS month,
                               YEAR(financialTransactionTime)  AS year,
                               financialTransactionAmount      AS amount
                        FROM FinancialTransaction
     ) FT ON CB.billingFinancialTransactionNumber = FT.transacNumber) Final
WHERE ranking <= 10;

-- Select top-10 customer transactions for branch #1 in January, 2018
-- The most comes first
SELECT *
FROM TopTenMonthlyBranchCustomerTransaction
WHERE branchNumber = 1 AND year = 2018 AND month = 1
ORDER BY ranking;




/**
  -- 31: Identify the average customer payment amount grouped by transaction type
  -- TODO: Transaction type?
 */
-- SELECT CBL.customerBillingNumber ,CBL.customerBillingLineNumber, UC.utilityCostNumber, CBL.customerBillingLineNumber, RRS.requestedLineNumber
-- FROM CustomerBillingLine CBL
--     LEFT JOIN UtilityCost UC ON CBL.customerBillingNumber = UC.utilityBillingNumber AND CBL.customerBillingLineNumber = UC.utilityLineNumber
--     LEFT JOIN RentalPeriod RP ON CBL.customerBillingNumber = RP.rentalPeriodBillingNumber AND CBL.customerBillingLineNumber = RP.rentalPeriodLineNumber
--     LEFT JOIN RequestedRoomService RRS ON CBL.customerBillingNumber = RRS.requestedBillingNumber AND CBL.customerBillingLineNumber = RRS.requestedLineNumber
-- CREATE VIEW TypeGroupedTransactionView AS
--     SELECT billingNumber,
--            customerBillingLineNumber,
--            financialTransactionCategory,
--            financialTransactionStatus
--     FROM CustomerBilling JOIN CustomerBillingLine JOIN FinancialTransaction
--     ON; /*ON not complete*/
--
-- SELECT *
-- FROM CustomerBilling CB JOIN CustomerBillingLine CBL
--     ON CB.billingNumber = CBL.customerBillingNumber
-- JOIN RequestedRoomService RRS ON CBL.customerBillingNumber = RRS.requestedBillingNumber AND CBL.customerBillingLineNumber = RRS.requestedLineNumber
-- JOIN RentalPeriod RP ON CBL.customerBillingNumber = RP.rentalPeriodBillingNumber AND CBL.customerBillingLineNumber = RP.rentalPeriodLineNumber;





/**
 * -- 46: List all Maintenance instances and preceding inspections
 *
 * If a maintenance instance does not preceded by any inspection, then it will not be displayed.
 */
CREATE VIEW MaintenancePrecedingInspectionView AS
SELECT maintenanceNumber,
       rentalBranchNumber branchNumber,
       dbo.funFormatFullRoomNumberString(rentalBranchNumber, rentalRoomNumber) room,
       maintenanceStatus,
       maintenanceStartingTime,
       maintenanceFinishedTime,
       maintenanceCategory,
       maintenanceDescription,
       propertyInspectionNumber inspectionNo,
       propertyInspectionEmployeeNum inspectionEmployee,
       propertyInspectionRentalNumber relatedRental
FROM PropertyInspection PINS
        LEFT JOIN PropertyDamage PD ON PINS.propertyInspectionNumber = PD.propertyDamageInspectionNumber
        LEFT JOIN Maintenance M ON M.maintenanceNumber = PD.propertyDamageMaintenanceNumber
        LEFT JOIN Rental R2 ON PINS.propertyInspectionRentalNumber = R2.rentalNumber


-- List all maintenance instances that are preceded by an inspection. The most recent comes first.
-- If not null condition is removed, all inspections done in branch #5 will be displayed.
SELECT *
FROM MaintenancePrecedingInspectionView
WHERE branchNumber = 5 AND maintenanceNumber IS NOT NULL ORDER BY maintenanceStartingTime DESC
