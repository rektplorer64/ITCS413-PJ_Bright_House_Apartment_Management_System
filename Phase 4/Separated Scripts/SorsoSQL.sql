USE BRIGHT_HOUSE
GO;

/**
  Returns a duration of time in years from a given pair of 2 different points in time.
 */
CREATE FUNCTION funCalculateAge(
    @dateOld datetime,
    @dateNew datetime
) RETURNS int
AS
BEGIN
    RETURN DATEDIFF(YY, @dateOld, @dateNew) - IIF(RIGHT(CONVERT(varchar(6), @dateNew, 12), 4) >=
                                                  RIGHT(CONVERT(varchar(6), @dateOld, 12), 4), 0, 1)
END
GO;

/**
  Returns a string that is a combination of First, Middle and Last name.
 */
CREATE FUNCTION funFormatFullNameString(
    @fullName   varchar(30),
    @middleName varchar(30),
    @lastName   varchar(30)
) RETURNS varchar(92)
AS
BEGIN
    RETURN @fullName + ' ' + IIF(@middleName IS NOT NULL, @middleName + ' ', '') + @lastName
END
GO;

/**
  Returns an appropriately-formatted room number string from a given branch and room number.
 */
CREATE FUNCTION funFormatFullRoomNumberString(
    @branch     int,
    @roomNumber int
) RETURNS varchar(5)
AS
BEGIN
    RETURN CAST(CONCAT(CAST(@branch AS varchar), CAST(@roomNumber AS varchar)) AS int)
END
GO;


/**
 * -- 18: List branch by a region
 *
 * List branches with respect to the region that, in this case, is a province.
 */
CREATE PROCEDURE spListBranchByRegion(
    @province varchar(40)
)
AS
BEGIN
    SET NOCOUNT ON

    IF @province IS NULL
        RETURN NULL

    SELECT branchNumber, branchName, branchEmail, branchDistrict, branchProvince, COUNT(employeeNum) AS totalEmployee
    FROM Branch
             JOIN Employee E ON Branch.branchNumber = E.employeeBranchNumber
    WHERE branchProvince = @province
    GROUP BY branchNumber, branchName, branchEmail, branchDistrict, branchProvince
END
GO;

EXEC spListBranchByRegion 'Chonburi'
GO;



SELECT *
FROM Employee
         JOIN Manager M ON Employee.employeeNum = M.managerNum

SELECT *
FROM Employee
         JOIN CleaningPersonnel M ON Employee.employeeNum = M.cleaningPersonnelNum

SELECT *
FROM Employee
         JOIN Accountant M ON Employee.employeeNum = M.accountantNum

GO;

/**
 * -- 19: List employee by given details
 *
 * List details of employees that match with the given criteria that can be either
 * employee number, first name, last name, branch number.
 *
 * If all parameters are set to NULL, it will return all employees in the table.
 */
CREATE PROCEDURE spListEmployeeByGivenDetails(
    @employeeNum  int,
    @name         varchar(30),
    @surname      varchar(30),
    @branchNumber int
)
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @queryEmployeeNum varchar(8)
    DECLARE @queryBranchNumber varchar(2)

    -- Handle in case that the employee number is not provided
    IF @employeeNum IS NULL
        -- Set the employee number to wildcard since it is not specified
        SET @queryEmployeeNum = '%'
    ELSE
        SET @queryEmployeeNum = CAST(@employeeNum AS varchar(2))

    IF @name IS NULL
        SET @name = '%'
    IF @surname IS NULL
        SET @surname = '%'

    -- Handle in case that the branch number is not provided
    IF @branchNumber IS NULL
        SET @queryBranchNumber = '%'
    ELSE
        -- Set the branch number to wildcard since it is not specified
        SET @queryBranchNumber = CAST(@branchNumber AS varchar(2))


    SELECT employeeDetails.*, employeeRole.employeeRole
    FROM (
         SELECT employeeNum,
                dbo.funFormatFullNameString(employeeFirstName, employeeMiddleName, employeeLastName)
                    AS employeeFullName,
                dbo.funCalculateAge(employeeDOB, current_timestamp)
                    AS employeeAge,
                branchNumber,
                branchName
         FROM (
              SELECT *
              FROM Employee
              WHERE employeeNum LIKE @queryEmployeeNum) Employee
                  JOIN Branch B2 ON Employee.employeeBranchNumber = B2.branchNumber
         WHERE employeeFirstName LIKE @name
           AND employeeLastName LIKE @surname
           AND branchNumber LIKE @queryBranchNumber) employeeDetails
             JOIN
         (
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
              FROM Employee
              WHERE employeeFirstName LIKE @name
                AND employeeLastName LIKE @surname
                AND employeeBranchNumber LIKE @queryBranchNumber) X
                  LEFT JOIN Manager M ON X.employeeNum = M.managerNum
                  LEFT JOIN Accountant A ON X.employeeNum = A.accountantNum
                  LEFT JOIN CleaningPersonnel CP ON X.employeeNum = CP.cleaningPersonnelNum
         ) employeeRole
         ON employeeRole.employeeNum = employeeDetails.employeeNum
    -- This select query works fine in SQL Server 2019, it will
    -- implicitly cast integer type to varchar automatically,
    -- so that we can use the LIKE operator.
END
GO;

EXEC spListEmployeeByGivenDetails NULL, NULL, NULL, NULL;
EXEC spListEmployeeByGivenDetails 2, NULL, NULL, NULL;
EXEC spListEmployeeByGivenDetails NULL, 'Apisit', NULL, NULL;
EXEC spListEmployeeByGivenDetails NULL, NULL, NULL, 1;

GO;

/**
 * -- 32: List Average Payment done by customers in each demographic (or nationality).
 *
 * List details of customers in terms of total billing, average billing, count by genders, average age
 * grouped by customer nationality.
 */
CREATE VIEW AvgCustomerDemographicPaymentView
AS
SELECT nationalityBilling.*, maleCustomerCount, femaleCustomerCount, totalCustomers
FROM (
     SELECT customerNationality                                 AS nationality,
            dbo.funCalculateAge(customerDOB, CURRENT_TIMESTAMP) AS averageAge,
            AVG(billingSum)                                     AS averageBillingSum,
            SUM(BILLINGSUM)                                     AS totalBillingSum
     FROM
         -- Identify customer billing sum and its payer
         (
         SELECT SUM(customerBillingAmount) AS billingSum, billingCustomerNum
         FROM CustomerBilling CB
                  JOIN CustomerBillingLine CBL ON CB.billingNumber = CBL.customerBillingNumber
         GROUP BY customerBillingNumber, billingCustomerNum) A
             JOIN Customer ON billingCustomerNum = customerNum
         -- Group customers by nationality, and counts
     GROUP BY customerNationality) AS nationalityBilling --** The first JOIN operand table is named "nationalityBilling"
         JOIN (
              -- Identify male and female count of each nationality
              SELECT A.customerNationality,
                     A.count           AS maleCustomerCount,
                     B.count           AS femaleCustomerCount,
                     A.count + B.count AS totalCustomers
              FROM (
                   SELECT COUNT(DISTINCT customerNum) AS count, customerNationality
                   FROM Customer C
                   WHERE C.customerGender = 'M'
                   GROUP BY customerNationality) A
                       JOIN (
                            SELECT COUNT(DISTINCT customerNum) AS count, customerNationality
                            FROM Customer C
                            WHERE C.customerGender = 'F'
                            GROUP BY customerNationality) B
                            ON A.customerNationality = B.customerNationality
) AS nationalityGenderCount --** The first JOIN operand table is named "nationalityGenderCount"
              ON nationalityGenderCount.customerNationality = nationalityBilling.nationality
GO;
-- Identify the average age, billing sum of customers from each nationality.
SELECT * FROM AvgCustomerDemographicPaymentView


/**
 * -- 33: List Highest Customer Payment grouped by Month and Customer's nationality
 *
 * Identify the customer payment that has the highest amount of money grouped by month, customer's nationality.
 */
CREATE VIEW MonthlyHighestCustomerPaymentView AS
SELECT month, year, C.customerNationality, MAX(billingAmount) AS maxPaymentAmount
FROM (
     SELECT customerBillingNumber,
            billingCustomerNum,
            SUM(customerBillingAmount) AS billingAmount,
            MONTH(customerBillingTime) AS month,
            YEAR(customerBillingTime)  AS year
     FROM CustomerBilling
              JOIN CustomerBillingLine CBL ON CustomerBilling.billingNumber = CBL.customerBillingNumber
     GROUP BY customerBillingNumber, customerBillingTime, billingCustomerNum
     ) B
         JOIN Customer C ON C.customerNum = B.billingCustomerNum
GROUP BY C.customerNationality, month, year;


/**
 * -- 34: Identify Customers by Rental Details
 *
 * List the customer payment by a given rental number or customer details.
 */
CREATE PROCEDURE spIdentifyCustomersByRentalDetails(
    @rentalNumber int
)
AS
BEGIN
    SET NOCOUNT ON

    IF @rentalNumber IS NULL
        THROW 50001, 'No Rental number specified', 1
    ELSE
        SELECT customerNum,
               dbo.funFormatFullNameString(customerFirstName, customerMiddleName, customerLastName) AS fullName,
               dbo.funCalculateAge(customerDOB, CURRENT_TIMESTAMP)                                  AS age,
               customerProfession                                                                   AS profession,
               customerNationality                                                                  AS nationality,
               customerEmail                                                                        AS email,
               string_agg(customerTelephoneNumber, ';')                                             AS telephoneNumbers
        FROM (
             SELECT * FROM RentalCustomer WHERE rentalCustomerRentalNumber = @rentalNumber) RC
                 JOIN Customer C ON RC.rentalCustomerNum = C.customerNum
                 LEFT JOIN CustomerTelephone ON C.customerNum = CustomerTelephone.telephoneCustomerNum
        GROUP BY customerNum, dbo.funFormatFullNameString(customerFirstName, customerMiddleName, customerLastName),
                 dbo.funCalculateAge(customerDOB, CURRENT_TIMESTAMP), customerEmail, customerNationality,
                 customerProfession;
END
GO;

EXEC spIdentifyCustomersByRentalDetails 1


/**
 * -- 35: List Average Customer Payment grouped by Month and Customer's nationality
 *
 * Identify the average amount of customer payments grouped by month and customer's nationality.
 */
CREATE VIEW MonthlyAvgCustomerPaymentView AS
SELECT month, year, C.customerNationality, AVG(billingAmount) AS averagePaymentAmount
FROM (
     SELECT customerBillingNumber,
            billingCustomerNum,
            SUM(customerBillingAmount) AS billingAmount,
            MONTH(customerBillingTime) AS month,
            YEAR(customerBillingTime)  AS year
     FROM CustomerBilling
              JOIN CustomerBillingLine CBL ON CustomerBilling.billingNumber = CBL.customerBillingNumber
     GROUP BY customerBillingNumber, customerBillingTime, billingCustomerNum
     ) B
         JOIN Customer C ON C.customerNum = B.billingCustomerNum
GROUP BY C.customerNationality, month, year;


/**
 * -- 36: List the frequency of starting and the frequency ending rentals in each month
 *
 * For each month that has rental entry, identify the frequency of rentals that are started &
 * the frequency of rentals that are ended as well as the differences between the two.
 */
CREATE VIEW MonthlyRentalFrequencyView AS
SELECT MONTH,
       YEAR,
       SUM(COALESCE(totalNewRentals, 0))                                        AS totalNewRentals,
       SUM(COALESCE(totalEndingRentals, 0))                                     AS totalEndingRentals,
       SUM(COALESCE(totalNewRentals, 0)) - SUM(COALESCE(totalEndingRentals, 0)) AS differences
FROM (
     SELECT COALESCE(NewRental.Month, EndingRental.Month) AS MONTH,
            COALESCE(NewRental.YEAR, EndingRental.YEAR)   AS YEAR,
            totalNewRentals,
            totalEndingRentals
     FROM
         -- Identify frequency of months that has at least a new rental
         (
         SELECT MONTH(rentalStartingTime) AS month,
                YEAR(rentalStartingTime)  AS year,
                COUNT(rentalNumber)       AS totalNewRentals
         FROM Rental
         GROUP BY MONTH(rentalStartingTime),
                  YEAR(rentalStartingTime)) NewRental
             FULL OUTER JOIN
         -- Identify frequency of months that has at least an ending rental
             (
             SELECT MONTH(rentalEndingTime) AS month,
                    YEAR(rentalEndingTime)  AS year,
                    COUNT(rentalNumber)     AS totalEndingRentals
             FROM Rental
             GROUP BY MONTH(rentalEndingTime),
                      YEAR(rentalEndingTime)) EndingRental
             -- Full Outer join both together since there maybe some months that has either a new rental or an ending rental.
         ON (EndingRental.Month IS NULL OR NewRental.Month IS NULL) AND
            (EndingRental.YEAR IS NULL OR NewRental.Year IS NULL)) AS NRER
GROUP BY MONTH, YEAR;


/**
 * -- 37: List expiring rentals in time range
 *
 * Identify rentals that will expire in a given time range.
 */
CREATE PROCEDURE spListExpiringRentalsInTimeRange(
    @timeRangeStart datetime,
    @timeRangeEnd   datetime
)
AS
BEGIN
    SET NOCOUNT ON

    -- If the given beginning of the time range is not given, set it to the current time.
    IF @timeRangeStart IS NULL
        SET @timeRangeStart = CURRENT_TIMESTAMP

    -- If the given ending of the time range is not given set it to the next 3 days.
    IF @timeRangeEnd IS NULL
        SET @timeRangeEnd = DATEADD(DAY, 3, @timeRangeStart)

    IF @timeRangeStart > @timeRangeEnd
        THROW 50001, 'The beginning of the time range is greater than the end of the time range!', 1
    ELSE
        SELECT rentalNumber,
               dbo.funFormatFullRoomNumberString(rentalBranchNumber, rentalRoomNumber)              AS roomNumber,
               rentalEndingTime                                                                     AS rentalExpectedEndingTime,
               MAX(rentalPeriodEndingTime)                                                          AS rentalEndingTime,
               DATEDIFF(HOUR, rentalPeriodEndingTime, @timeRangeEnd)                                AS remainingDurationHours,
               customerNum,
               dbo.funFormatFullNameString(customerFirstName, customerMiddleName, customerLastName) AS customerFullName
        FROM Rental
                 JOIN RentalPeriod RP ON Rental.rentalNumber = RP.rentalPeriodRentalNumber
                 JOIN Customer C ON Rental.rentalBookingCustomerNum = C.customerNum
        WHERE rentalPeriodEndingTime BETWEEN @timeRangeStart AND @timeRangeEnd
        GROUP BY rentalNumber, rentalRoomNumber, rentalEndingTime, customerNum, customerFirstName, customerMiddleName,
                 customerLastName, rentalPeriodEndingTime, rentalBranchNumber
END
GO;

EXEC spListExpiringRentalsInTimeRange '2017-07-27 11:03:04.137', NULL;


/**
 * -- 38: List free rooms in a given time range
 *
 * Identify rooms that is not occupied or reserved during the time range.
 */
CREATE PROCEDURE spListFreeRoomInGivenTimeRange(
    @timeRangeStart datetime,
    @timeRangeEnd   datetime
)
AS
BEGIN
    SET NOCOUNT ON

    -- If the given beginning of the time range is not given, set it to the current time.
    IF @timeRangeStart IS NULL
        SET @timeRangeStart = CURRENT_TIMESTAMP

    -- If the given ending of the time range is not given set it to the next 3 months.
    IF @timeRangeEnd IS NULL
        SET @timeRangeEnd = DATEADD(MONTH, 3, @timeRangeStart)

    IF @timeRangeStart > @timeRangeEnd
        THROW 50001, 'The beginning of the time range is greater than the end of the time range!', 1
    ELSE
        SELECT roomBranchNumber AS branch, dbo.funFormatFullRoomNumberString(roomBranchNumber, roomNumber) AS roomNumber, roomFloor, roomSize
        FROM Room R
             -- If the room is not exists in...
        WHERE NOT EXISTS(SELECT *
                         FROM Rental
                                  JOIN (
                                       SELECT *
                                       FROM Room
                                       WHERE roomNumber = R.roomNumber
                                         AND roomBranchNumber = R.roomBranchNumber) R2
                                       ON rentalRoomNumber = R2.roomNumber
                              -- Where the rental is overlapping with the given time range
                         WHERE (rentalStartingTime <= @timeRangeEnd)
                           AND (rentalEndingTime >= @timeRangeStart))
        INTERSECT -- <~~ Both Conditions must be true
        SELECT roomBranchNumber AS branch, dbo.funFormatFullRoomNumberString(roomBranchNumber, roomNumber) AS roomNumber, roomFloor, roomSize
        FROM Room R
             -- If the room is not exists in...
        WHERE NOT EXISTS(SELECT *
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
                         WHERE (expectedCheckInDate <= @timeRangeEnd)
                           AND (expectedCheckOutDate >= @timeRangeStart))
        ORDER BY roomNumber DESC

END
GO;

EXEC spListFreeRoomInGivenTimeRange '2016-11-11', NULL;


/**
 * -- 39: List all rentals in any branches associated with a given customer
 *
 * Show all rentals associate with a customer.
 */
CREATE PROCEDURE spListAllRentalsByCustomerNumber(
    @customerNum int
)
AS
BEGIN
    SET NOCOUNT ON

    IF @customerNum IS NULL
        THROW 50001, 'No customer number is given...', 1
    ELSE
        SELECT rentalNumber,
               rentalType,
               rentalDeposit,
               rentalStartingTime,
               rentalEndingTime,
               DATEDIFF(MONTH, rentalStartingTime, rentalEndingTime)                   AS rentalDurationMonth,
               dbo.funFormatFullRoomNumberString(rentalBranchNumber, rentalRoomNumber) AS rentalRoomNumber
        FROM Rental
                 JOIN (
                      SELECT *
                      FROM RentalCustomer
                      WHERE rentalCustomerNum = @customerNum) RC ON Rental.rentalNumber = RC.rentalCustomerRentalNumber
                 JOIN (
                      SELECT *
                      FROM Customer
                      WHERE customerNum = @customerNum) C ON rentalCustomerNum = C.customerNum

END
GO;

EXEC spListAllRentalsByCustomerNumber 2;


/**
 * -- 40: For each service instance, List all room service details including its category, total actions done, starting time.
 */
CREATE VIEW IndividualRoomServiceView
AS
SELECT dbo.funFormatFullRoomNumberString(rentalBranchNumber, rentalRoomNumber) AS roomNumber,
       R3.serviceNumber,
       serviceCategory,
       IIF(CustomerRoomService.serviceType = 'R', 'Resupply', 'Cleaning')      AS serviceType,
       actionCount,
       actions,
       R3.serviceRentalNumber,
       serviceStartTime,
       serviceEndTime
FROM CustomerRoomService
         JOIN CleaningPersonnel CP ON CustomerRoomService.serviceCleaningPersonalNum = CP.cleaningPersonnelNum
         JOIN Rental R2 ON CustomerRoomService.serviceRentalNumber = R2.rentalNumber
         JOIN (
              -- Flatten subtypes' properties; ** Subtype includes RoutineRoomService & RequestedRoomService
              SELECT C.serviceNumber,
                     COALESCE(
                             IIF(R.requestedServiceNumber IS NOT NULL, 'Requested Service', NULL),
                             IIF(RRS.routineServiceNumber IS NOT NULL, 'Routine Service', NULL),
                             'Undefined'
                         )                                                              AS serviceCategory,
                     COALESCE(RRXN.totalServiceActionDone, RRJN.totalServiceActionDone) AS actionCount,
                     COALESCE(RRJN.actions, RRXN.actions, 'Undefined')                  AS actions,
                     serviceType,
                     serviceRentalNumber
              FROM CustomerRoomService C
                       -- Join with Requested Room Service and its associated service actions
                       LEFT JOIN RequestedRoomService R ON C.serviceNumber = R.requestedServiceNumber
                       LEFT JOIN (
                                 SELECT requestedServiceNumber,
                                        COUNT(performRequestedServiceNumber) AS totalServiceActionDone,
                                        STRING_AGG(roomServiceNumber, ';')   AS actions
                                 FROM RequestedRoomService RRS
                                          JOIN RequestedPerformedRoomServiceAction RPRSA
                                               ON RRS.requestedServiceNumber = RPRSA.performRequestedServiceNumber
                                          JOIN RoomServiceAction RSA
                                               ON performRequestedRoomServiceNumber = RSA.roomServiceNumber
                                 GROUP BY requestedServiceNumber) RRXN
                                 ON RRXN.requestedServiceNumber = R.requestedServiceNumber
                  -- Join with Routine Room Service and its associated service actions
                       LEFT JOIN RoutineRoomService RRS ON C.serviceNumber = RRS.routineServiceNumber
                       LEFT JOIN (
                                 SELECT performRoutineServiceNumber,
                                        COUNT(performRoutineRoomServiceNumber) AS totalServiceActionDone,
                                        STRING_AGG(roomServiceNumber, ';')     AS actions
                                 FROM RoutineRoomService
                                          JOIN RoutinePerformedRoomServiceAction RPRSA
                                               ON RoutineRoomService.routineServiceNumber =
                                                  RPRSA.performRoutineServiceNumber
                                          JOIN RoomServiceAction RSA
                                               ON performRoutineRoomServiceNumber = RSA.roomServiceNumber
                                 GROUP BY performRoutineServiceNumber) RRJN
                                 ON RRJN.performRoutineServiceNumber = RRS.routineServiceNumber) R3
              ON R3.serviceNumber = CustomerRoomService.serviceNumber;


/**
 * -- 41: For a given rental, List all room service details including its category, total actions done, starting time.
 */
CREATE PROCEDURE spListRoomServiceByRental(
    @rentalNumber int
)
AS
BEGIN
    SET NOCOUNT ON

    IF @rentalNumber IS NULL
        THROW 50001, 'There is no rental number provided!', 1
    ELSE
        SELECT serviceNumber,
               serviceCategory,
               COUNT(actionPair)                                  AS totalActions,
               STRING_AGG(actionPair, ',')                        AS actions,
               serviceStartTime,
               serviceEndTime,
               DATEDIFF(MINUTE, serviceStartTime, serviceEndTime) AS durationMinutes
        FROM (
             SELECT serviceNumber,
                    serviceCategory,
                    '{' + value + ':"' + RSA.serviceName + '"}' AS actionPair,
                    serviceStartTime,
                    serviceEndTime
             FROM IndividualRoomServiceView
                      CROSS APPLY STRING_SPLIT(actions, ';') -- Separate aggregated actionNumber String and use it as a value for the table
                      JOIN RoomServiceAction RSA ON value = RSA.roomServiceNumber
             WHERE serviceRentalNumber = @rentalNumber
             ) X
        GROUP BY serviceNumber, serviceCategory, serviceStartTime, serviceEndTime
END
GO;

EXEC spListRoomServiceByRental 4;


/**
 * -- 42: For each branch, retrieve information regarding rentals and customers such as rental duration, PAX, etc.
 * Then summarize them with average or total sum.
 */
CREATE VIEW BranchAvgRentalAndCustomerView
AS
SELECT branchNumber,
       COUNT(DISTINCT rentalNumber)                             AS totalRentals,
       COUNT(ALL rentalCustomerNum)                             AS totalCustomers,
       COUNT(DISTINCT rentalCustomerNum)                        AS totalUniqueCustomers,
       AVG(DATEDIFF(DAY, rentalStartingTime, rentalEndingTime)) AS averageRentalDurationDay,
       AVG(PAX)                                                 AS averagePAX
FROM (
     SELECT branchNumber, rentalNumber, rentalCustomerNum, rentalStartingTime, rentalEndingTime, PAX
     FROM Rental
              JOIN Room R2
                   ON Rental.rentalBranchNumber = R2.roomBranchNumber AND Rental.rentalRoomNumber = R2.roomNumber
              JOIN RentalCustomer RC ON Rental.rentalNumber = RC.rentalCustomerRentalNumber
              JOIN Branch B ON R2.roomBranchNumber = B.branchNumber
              JOIN (
                   -- To find the average PAX, we must count them by each rental first.
                   SELECT rentalNumber AS rentalNum, COUNT(rentalCustomerNum) AS PAX
                   FROM Rental
                            JOIN RentalCustomer C ON Rental.rentalNumber = C.rentalCustomerRentalNumber
                   GROUP BY rentalNumber
     ) RentalPAX ON RentalPAX.rentalNum = RC.rentalCustomerRentalNumber) A
GROUP BY branchNumber




/**
 * -- 43: Insert the details of a Property Inspection
 */
CREATE PROCEDURE spInsertPropertyInspection(
    @rentalNumber int,
    @employeeNum int,
    @description varchar(400)
)
AS
BEGIN
    SET NOCOUNT ON
    BEGIN TRANSACTION
    BEGIN TRY

        IF @rentalNumber IS NULL
            THROW 50001, 'A rental number is not provided!', 1

        IF @employeeNum IS NULL
            THROW 50001, 'An employee number is not provided!', 1

        IF @description IS NULL
            THROW 50001, 'A description of the inspection  is not provided!', 1

        -- Retrieve the last Number of PropertyInspection for the insertion of a new record.
        DECLARE @maxInspectionNumber int
        SELECT @maxInspectionNumber = (MAX(propertyInspectionNumber) + 1) FROM PropertyInspection

        -- Retrieve Branch Number and Room Number associated with the given rental
        DECLARE @branchNumber int
        DECLARE @roomNumber int
        SELECT @branchNumber = rentalBranchNumber, @roomNumber = rentalRoomNumber FROM Rental WHERE rentalNumber = @rentalNumber

        -- Insert the property inspection
        INSERT INTO PropertyInspection
        VALUES (@maxInspectionNumber, CURRENT_TIMESTAMP, @description, @employeeNum, @rentalNumber, @branchNumber, @roomNumber)

        SELECT * FROM PropertyInspection WHERE propertyInspectionNumber = @maxInspectionNumber
    END TRY
    BEGIN CATCH

        DECLARE @Message varchar(max) = ERROR_MESSAGE(),
            @Severity int = ERROR_SEVERITY(),
            @State smallint = ERROR_STATE()

        RAISERROR (@Message, @Severity, @State)

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
    END CATCH

    IF @@TRANCOUNT > 0
        COMMIT TRANSACTION;
END
GO;

EXEC spInsertPropertyInspection 1, 1, 'Everything is good!';