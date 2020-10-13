/**
  README: This file stores SQL COMMANDS that **DISPLAY / SHOWS / RETURNS** DATA by using STORED PROCEDURES OR VIEWS.
 */

-- RUN THIS COMMAND BEFORE GOING FURTHER!
USE BRIGHT_HOUSE
GO;

/**
 * -- P10.1: Get Current Rental by a Customer
 */
EXEC spGetRentalDuringTimeByCustomerNum 10, '2019-11-15 11:38:58.380'
GO;


/**
 * -- P10.2: Get Current CustomerBill by RentalNum
 */
EXEC spGetLatestCustomerBillingByRentalNum 1323, '2019-11-15 11:38:58.380'
GO;


/**
 * -- P10.3: Get Latest BillingLine by BillingNumber
 */
EXEC spGetLatestBillingLineByBillingNum 583
GO;


/**
 * -- P12.1: Retrieve the number of a returning supply so far given a branch.
 */
EXEC spIdentifyReturningSupplyOnHandQuantity 18, 1;


/**
 * -- P12.2: Find Branch Number from a given employee number
 */
EXEC spFindBranchOfGivenEmployeeNum 41;
GO;


/**
 * -- P12.3: Find accountant number by a branch number
 */
EXEC spFindAccountantByBranchNum 8;
GO;


/**
 * -- P15: List branches by a region
 */
EXEC spListBranchByRegion 'Chonburi'
GO;


/**
 * -- P16: List employee by given details
 */
-- Not providing any information will return all employees
EXEC spListEmployeeByGivenDetails NULL, NULL, NULL, NULL;

EXEC spListEmployeeByGivenDetails 2, NULL, NULL, NULL;
EXEC spListEmployeeByGivenDetails NULL, 'Apisit', NULL, NULL;
EXEC spListEmployeeByGivenDetails NULL, NULL, NULL, 1;


/**
 * -- P17: For each Customer, List their rentals that are within the given time window.
 */
-- If there is no datetime param provided, it will use the time window between the past 6 months to the present.
EXEC spListCustomerRentalsByTimeWindow NULL, NULL;


/**
 * -- P18: Identify Customers by Rental Details
 */
EXEC spIdentifyCustomersByRentalDetails 1


/**
 * -- P19: List expiring rentals in time range
 */
EXEC spListExpiringRentalsInTimeRange '2017-07-27 11:03:04.137', NULL;


/**
 * -- P20: List free rooms in a given time range
 */
EXEC spListFreeRoomInGivenTimeRange '2016-11-11', NULL;


/**
 * -- P21: List all rentals in any branches associated with a given customer
 */
EXEC spListAllRentalsByCustomerNumber 2;


/**
 * -- P22: For a given rental, List all room service details including its category, total actions done, starting time.
 */
EXEC spListRoomServiceByRental 4;


/**
 * -- P26: Get Branch employee with max wage
 */
EXEC spGetBranchEmployeeWithMaxWage @branchNum = 2;
GO;


/**
 * -- P28: List the customer payment by a given rental number and customer name.
 */
EXEC spListCustomerPaymentByRentalCustomer 145, NULL
GO;


/**
 * -- V1: List all employees with respects to their role, daily wage, and average working hours.
 */
SELECT *
FROM EmployeeDetailsView
GO;


/**
 * -- V2: List the transactions to employees of branch #1 with the fifteenth week of 2019
 */
SELECT *
FROM EmployeePayrollView
WHERE branchNumber = 1
  AND DATEPART(WEEK, financialTransactionTime) = 15
  AND DATEPART(YEAR, financialTransactionTime) = 2019
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
-- List customers who lastly stayed at the branch #10
SELECT *
FROM CustomerView
WHERE lastRentalBranch = 10

-- List customers who had stayed and checked out with either in branch #1, #2 or #3 within the last 4 months
SELECT *
FROM CustomerView
WHERE lastRentalBranch IN (1, 2, 3)
  AND lastRentalEndingTime
    BETWEEN DATEADD(MONTH, -4, CURRENT_TIMESTAMP) AND CURRENT_TIMESTAMP
ORDER BY lastRentalEndingTime DESC


/**
 * -- V4: List the details of each type of supply for each branch
 */
-- Shows the summary of all supply types for the first branch
SELECT *
FROM SummarySupplyView
WHERE branchNumber = 1
ORDER BY supplyNumber


/**
 * -- V5: Show the summary of supply weekly usage in each branch
 */
-- Shows the usage of each supply type of the first branch at the fifteenth week of 2019
SELECT *
FROM WeeklySupplySummaryView
WHERE entryBranchNumber = 1
  AND weekOfYear = 15
  AND year = 2019
ORDER BY totalQuantityUsed DESC


/**
 * -- V6: List every room in all branches as well as identify its occupation or reservation status
 */
-- Retrieve the list of rooms that are not occupied and not reserved in branch #1
SELECT *
FROM RoomRentalStatusView
WHERE branchNumber = 1
  AND isOccupied = 'Free'
  AND isReserved = 'Not Reserved'
ORDER BY roomNumber;


/**
 * -- V7: List Average Payment done by customers in each demographic (or nationality).
 */
-- Identify the average age, billing sum of customers from each nationality.
SELECT *
FROM AvgCustomerDemographicPaymentView


/**
 * -- V8: List Highest Customer Payment grouped by Month and Customer's nationality
 */
-- Identify the average of the highest amount of payment during 2017 and 2019 of each nationality
SELECT customerNationality, AVG(maxPaymentAmount) AS AverageMaxPayment
FROM MonthlyHighestCustomerPaymentView
WHERE year BETWEEN 2017 AND 2019
GROUP BY customerNationality


/**
 * -- V9: List Average Customer Payment grouped by Month and Customer's nationality
 */
-- Identify the average of the average amount of payment during 2017 and 2019 of each nationality
SELECT customerNationality, AVG(averagePaymentAmount) AS AverageMaxPayment
FROM MonthlyAvgCustomerPaymentView
WHERE year BETWEEN 2017 AND 2019
GROUP BY customerNationality


/**
 * -- V10: List the frequency of starting and the frequency ending rentals in each month
 */
SELECT *
FROM MonthlyRentalFrequencyView
ORDER BY year, month


/**
 * -- V11: For each service instance, List all room service details including its category, total actions done, starting time.
 */
-- List all services done to a room 101 of branch #1 regardless the associated rental number
SELECT *
FROM IndividualRoomServiceView
WHERE roomNumber = 1101


/**
 * -- V12: For each branch, retrieve information regarding rentals and customers such as rental duration, PAX, etc.
 */
SELECT *
FROM BranchAvgRentalAndCustomerView
ORDER BY branchNumber


/**
 * -- V13: List all Maintenance instances and preceding inspections
 */
-- List all maintenance instances that are preceded by an inspection. The most recent comes first.
-- If not null condition is removed, all inspections done in branch #5 will be displayed.
SELECT *
FROM MaintenancePrecedingInspectionView
WHERE branchNumber = 5
  AND maintenanceNumber IS NOT NULL
ORDER BY maintenanceStartingTime DESC


/**
 * -- V14: List Top-10 customer transactions in each month along with associated customer details
 */
-- Select top-10 customer transactions for branch #1 in January, 2018
-- The one with the highest transaction amount comes first
SELECT *
FROM TopTenMonthlyBranchCustomerTransactionView
WHERE branchNumber = 1
  AND year = 2018
  AND month = 1
ORDER BY ranking;


/**
 * -- V15: List room number, customer name, rental type, deposit, rental amount, as well as supplies used by the room.
 */
-- Retrieve the rental and supply details of the rental number 1, 2 and 100
SELECT *
FROM RentalSupplyView
WHERE rentalNumber IN (1, 2, 100);


/**
 * -- V16: List the details of a Reservation number 34
 */
SELECT *
FROM CustomerReservationView
WHERE reservationNumber = 34;


/**
 * -- V17: List all information of branch that is important for customers
 */
SELECT *
FROM BranchContactView


/**
 * -- V18: List all Feedback given by the customer with the number = 25 sorted in an descending order by date given
 */
SELECT *
FROM CustomerFeedbackView
WHERE customerNum = 25
ORDER BY createdTime DESC