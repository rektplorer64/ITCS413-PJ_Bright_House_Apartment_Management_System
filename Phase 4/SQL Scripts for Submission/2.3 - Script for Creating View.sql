
/**
  README: This file stores SQL COMMANDS that create VIEWS that are used in database transactions
 */

-- RUN THIS COMMAND BEFORE GOING FURTHER!
USE BRIGHT_HOUSE
GO;



/**
 * -- V1: List the details of each employee including gender, branch, wage, position, working hour.
 */
CREATE VIEW EmployeeDetailsView AS
SELECT Roles.employeeNum,
       employeeCitizenId AS citizenId,
       employeeFullName AS fullName,
       employeeGender AS gender,
       employeeAge AS age,
       branchNumber,
       branchName,
       Roles.employeeRole AS position,
       dailyWage,
       AVG(workingShiftLengthHour) AS avgWorkingHourLengthPerDay
FROM (
     SELECT employeeNum,
            employeeCitizenId,
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
         employeeGender, employeeCitizenId
GO;




/**
 * -- V2: Identify the total employee payroll for day, week or month.
 */
CREATE VIEW EmployeePayrollView AS
SELECT employeeNum,
       employeeBranchNumber AS branchNumber,
       dbo.funFormatFullNameString(employeeFirstName, employeeMiddleName, employeeLastName) AS employeeFullName,
       dailyWage, financialTransactionNumber, financialTransactionAmount, financialTransactionTime
FROM Employee E
    JOIN EmployeeWagePayment EWP ON E.employeeNum = EWP.wagePaymentEmployeeNum
    JOIN FinancialTransaction FT ON EWP.wagePaymentFinancialTransactionNumber = FT.financialTransactionNumber;
GO;



/**
 * -- V3: Identify customer information as well as his/her first rental branch.
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
       customerNickName                                                                     AS nickname,
       dbo.funCalculateAge(customerDOB, CURRENT_TIMESTAMP)                                  AS age,
       customerGender                                                                       AS gender,
       customerProfession                                                                   AS profession,
       customerNationality                                                                  AS nationality,
       customerEmail                                                                        AS email,
       latestPassport,
       latestVisa,
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
) LV ON CX.customerNum = LV.rentalCustomerNum
         LEFT JOIN (
                   SELECT DISTINCT passportCustomerNum,
                                   latestPassport,
                                   FIRST_VALUE(visaNumber)
                                               OVER (PARTITION BY passportCustomerNum, latestPassport ORDER BY arrivalDate DESC) AS latestVisa
                   FROM (
                        SELECT passportCustomerNum,
                               FIRST_VALUE(passportNumber)
                                           OVER (PARTITION BY passportCustomerNum ORDER BY expirationDate DESC) AS latestPassport
                        FROM CustomerPassport) P
                            JOIN CustomerVisa CV ON P.latestPassport = CV.visaPassportNumber
) PassportVisa ON passportCustomerNum = CX.customerNum;
GO;



/**
 * -- V4: List the details of each type of supply for each branch
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
         SELECT entryBranchNumber AS branchNumber,
                entrySupplyNumber AS supplyNumber,
                COUNT(entryNumber)      AS totalEntries,
                SUM(supplyUnitQuantity) AS quantityTransferred
         FROM Branch
                  JOIN InventoryEntry ON Branch.branchNumber = InventoryEntry.entryBranchNumber
                  JOIN Supply S ON InventoryEntry.entrySupplyNumber = S.supplyNumber
         GROUP BY entryBranchNumber, entrySupplyNumber
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
        SELECT S.supplyNumber, Withdrawing.count AS withdrawQuantity,
               Purchasing.count AS purchasingQuantity,
               Returning.count AS returningQuantity
        FROM Supply S
            JOIN (SELECT entrySupplyNumber, SUM(supplyUnitQuantity) AS count FROM InventoryEntry WHERE inventoryEntryType = 'W' GROUP BY entrySupplyNumber) Withdrawing
                ON S.supplyNumber = Withdrawing.entrySupplyNumber
            JOIN (SELECT entrySupplyNumber, SUM(supplyUnitQuantity) AS count FROM InventoryEntry WHERE inventoryEntryType = 'P' GROUP BY entrySupplyNumber) Purchasing
                ON S.supplyNumber = Purchasing.entrySupplyNumber
            JOIN (SELECT entrySupplyNumber, SUM(supplyUnitQuantity) AS count FROM InventoryEntry WHERE inventoryEntryType = 'R' GROUP BY entrySupplyNumber) Returning
                ON S.supplyNumber = Returning.entrySupplyNumber
    ) K ON X.supplyNumber = K.supplyNumber
GO;



/**
 * -- V5: Show the summary of supply weekly usage in each branch
 */
CREATE VIEW WeeklySupplySummaryView AS
    SELECT entryBranchNumber, entrySupplyNumber AS supplyNumber, supplyName, supplyCategory,
           DATEPART(WEEK, overseeingTimestamp) AS weekOfYear,
           DATEPART(YEAR, overseeingTimestamp) AS year,
           SUM(supplyUnitQuantity) AS totalQuantityUsed
    FROM Supply JOIN InventoryEntry
    ON Supply.supplyNumber = InventoryEntry.entrySupplyNumber
    WHERE inventoryEntryType = 'W'
    GROUP BY entryBranchNumber, entrySupplyNumber, overseeingTimestamp, supplyName, supplyCategory
GO;




/**
 * -- V6: List every room in all branches as well as identify its occupation or reservation status
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
                                              ON rentalRoomNumber = R2.roomNumber AND rentalBranchNumber = R2.roomBranchNumber
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
                                ON reservedRoomNumber = R2.roomNumber AND reserveBranchNumber = R2.roomBranchNumber
                       -- When the expected reservation time range is overlapping with the given time range
                  WHERE CURRENT_TIMESTAMP BETWEEN expectedCheckInDate AND expectedCheckOutDate)) B
     ON B.roomBranchNumber = XR.roomBranchNumber AND B.roomNumber = XR.roomNumber
JOIN Branch B2 ON XR.roomBranchNumber = B2.branchNumber
GO;



/**
 * -- V7: List Average Payment done by customers in each demographic (or nationality).
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
     GROUP BY customerNationality, customerDOB) AS nationalityBilling --** The first JOIN operand table is named "nationalityBilling"
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



/**
 * -- V8: List Highest Customer Payment grouped by Month and Customer's nationality
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
GO;


/**
 * -- V9: List Average Customer Payment grouped by Month and Customer's nationality
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
GO;


/**
 * -- V10: List the frequency of starting and the frequency ending rentals in each month
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
     SELECT COALESCE(NewRental.Month, EndingRental.Month) AS month,
            COALESCE(NewRental.YEAR, EndingRental.YEAR)   AS year,
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
GO;



/**
 * -- V11: For each service instance, List all room service details including its category, total actions done, starting time.
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
                                 SELECT routineServiceNumber,
                                        COUNT(performRoutineRoomServiceNumber) AS totalServiceActionDone,
                                        STRING_AGG(roomServiceNumber, ';')     AS actions
                                 FROM RoutineRoomService
                                          JOIN RoutinePerformedRoomServiceAction RPRSA
                                               ON RoutineRoomService.routineServiceNumber =
                                                  RPRSA.performRoutineServiceNumber
                                          JOIN RoomServiceAction RSA
                                               ON performRoutineRoomServiceNumber = RSA.roomServiceNumber
                                 GROUP BY routineServiceNumber) RRJN
                                 ON RRJN.routineServiceNumber = RRS.routineServiceNumber) R3
              ON R3.serviceNumber = CustomerRoomService.serviceNumber;
GO;



/**
 * -- V12: For each branch, retrieve information regarding rentals and customers such as rental duration, PAX, etc.
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
     FROM Branch B
          JOIN Room R2 ON B.branchNumber = R2.roomBranchNumber
          JOIN Rental ON R2.roomBranchNumber = Rental.rentalBranchNumber AND R2.roomNumber = Rental.rentalRoomNumber
          JOIN RentalCustomer RC ON Rental.rentalNumber = RC.rentalCustomerRentalNumber
          JOIN (
               -- To find the average PAX, we must count them by each rental first.
               SELECT rentalNumber AS rentalNum, COUNT(rentalCustomerNum) AS PAX
               FROM Rental
                        JOIN RentalCustomer C ON Rental.rentalNumber = C.rentalCustomerRentalNumber
               GROUP BY rentalNumber
          ) RentalPAX ON RentalPAX.rentalNum = RC.rentalCustomerRentalNumber) A
GROUP BY branchNumber
GO;



/**
 * -- V13: List all Maintenance instances and preceding inspections
 *
 * If a maintenance instance does not preceded by any inspection, then it will not be displayed.
 */
CREATE VIEW MaintenancePrecedingInspectionView AS
SELECT maintenanceNumber,
       rentalBranchNumber AS branchNumber,
       dbo.funFormatFullRoomNumberString(rentalBranchNumber, rentalRoomNumber) AS room,
       maintenanceStatus,
       maintenanceStartingTime,
       maintenanceFinishedTime,
       maintenanceCategory,
       maintenanceDescription,
       propertyInspectionNumber AS inspectionNo,
       propertyInspectionEmployeeNum AS inspectionEmployee,
       propertyInspectionRentalNumber AS relatedRental
FROM PropertyInspection PINS
        LEFT JOIN PropertyDamage PD ON PINS.propertyInspectionNumber = PD.propertyDamageInspectionNumber
        LEFT JOIN Maintenance M ON M.maintenanceNumber = PD.propertyDamageMaintenanceNumber
        LEFT JOIN Rental R2 ON PINS.propertyInspectionRentalNumber = R2.rentalNumber
GO;



/**
 * -- V14: List Top-10 customer transactions in each month along with associated customer details
 *
 * Rank financial transaction in each month by the amount
 * Then join the result with the associated customer
 */
CREATE VIEW TopTenMonthlyBranchCustomerTransactionView AS
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
            row_number() OVER (PARTITION BY rentalBranchNumber, month, year ORDER BY amount DESC) AS ranking
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
GO;



/**
 * -- V15: List room number, customer name, rental type, deposit, rental amount, as well as supplies used by the room.
 */
CREATE VIEW RentalSupplyView
AS
SELECT A.rentalNumber,
       rentalStartingTime,
       periodStartTime,
       rentalBranchNumber       AS branch,
       rentalRoomNumber         AS roomNumber,
       COUNT(rentalCustomerNum) AS PAX,
       totalBillingAmount,
       rentalDeposit,
       XZ.supplyNum,
       SUM(XZ.quantity)         AS supplyCount
FROM (
     SELECT rentalNumber,
            rentalStartingTime,
            MAX(rentalPeriodStartingTime) AS periodStartTime,
            rentalBranchNumber,
            rentalRoomNumber,
            SUM(customerBillingAmount)    AS totalBillingAmount,
            rentalDeposit
     FROM Rental R
              JOIN CustomerBilling CB ON R.rentalNumber = CB.billingRentalNumber
              JOIN CustomerBillingLine CBL ON CB.billingNumber = CBL.customerBillingNumber
              JOIN RentalPeriod RP ON R.rentalNumber = RP.rentalPeriodRentalNumber
     GROUP BY rentalNumber, rentalStartingTime, rentalBranchNumber, rentalRoomNumber, rentalDeposit
     ) A
         JOIN RentalCustomer RC ON A.rentalNumber = RC.rentalCustomerRentalNumber
         JOIN (
              SELECT serviceRentalNumber,
                     COALESCE(entrySupplyNumber, entryReturningSupplyNumber) AS supplyNum,
                     SUM(supplyUnitQuantity)                                 AS quantity
              FROM InventoryEntry IE
                       JOIN CustomerRoomService CRS ON IE.entryServiceNumber = CRS.serviceNumber
              WHERE (inventoryEntryType = 'W' AND entrySupplyNumber IS NOT NULL)
                OR (inventoryEntryType = 'W' AND entryReturningSupplyNumber IS NOT NULL)
              GROUP BY serviceRentalNumber, entrySupplyNumber, entryReturningSupplyNumber) XZ
              ON XZ.serviceRentalNumber = rentalNumber
GROUP BY A.rentalNumber, rentalStartingTime, periodStartTime, rentalBranchNumber, rentalRoomNumber, totalBillingAmount,
         rentalDeposit, XZ.supplyNum;
GO;



/**
 * -- V16: List the details of a Reservation that customers have made.
 * (A customer can reserve a room and get the details of the Reservation that they have made)
 */
CREATE VIEW CustomerReservationView
AS
SELECT reservationNumber,
       R.reserveBranchNumber AS branchNumber,
       reservationCreatedTime,
       expectedCheckInDate,
       expectedCheckOutDate,
       proposedDepositAmount,
       proposedRentalPrice,
       dbo.funFormatFullNameString(bookingFirstName, bookingMiddleName, bookingLastName) AS bookingName,
       bookingContact,
       reservedRoomNumber    AS room,
       reserveCustomerNumber AS customerNum,
       reserveManagerNumber  AS managerNum
FROM Reservation R
         JOIN ReservedRoom RR ON R.reservationNumber = RR.reservedRoomReservationNumber;
GO;



/**
 * -- V17: List the Contacts details in each branch
 *
 * Shows important information of each branch such as branch number, branch name, branch address,
 * branch contacts as well as manager details.
 */
CREATE VIEW BranchContactView
AS
SELECT A.*, branchTelephoneNumber
FROM (
     SELECT B.*,
            dbo.funFormatFullNameString(employeeFirstName, employeeMiddleName, employeeLastName) AS managerFullname,
            employeeEmail                                                                        AS managerEmail,
            employeeNickname                                                                     AS managerNickname
     FROM Branch B
              JOIN Employee E ON B.branchNumber = E.employeeBranchNumber
              JOIN Manager M ON E.employeeNum = M.managerNum) A
         JOIN (
              SELECT RANK() OVER (PARTITION BY telephoneBranchNumber ORDER BY branchTelephoneNumber) AS rank,
                     telephoneBranchNumber,
                     branchTelephoneNumber
              FROM BranchTelephone) B ON A.branchNumber = B.telephoneBranchNumber WHERE rank = 1
GO;



/**
 * -- V18: List the Feedback that is submitted by the customer who gave the feedback
 */
CREATE VIEW CustomerFeedbackView
AS
SELECT feedbackNumber,
       feedbackDescription,
       satisfactionValue,
       feedbackStatus           AS rawStatus,
       (CASE feedbackStatus
            WHEN 'I' THEN 'Ignored'
            WHEN 'H' THEN 'High Priority'
            WHEN 'L' THEN 'Low Priority'
            WHEN 'R' THEN 'Reviewed'
            ELSE 'Unknown' END) AS status,
       feedbackCreatedTime AS createdTime,
       feedbackEmployeeNum AS employeeNum,
       feedbackCustomerNum AS customerNum
FROM Feedback F
GO;





