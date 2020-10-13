
/**
  README: Run all SQL commands in this file before going to other SQL files.
 */

USE BRIGHT_HOUSE
GO


/**
  Section 0: Changing branch number of an accountant such that every branch has an accountant
 */
UPDATE Employee SET employeeBranchNumber = 10 WHERE employeeNum = 23;
GO;

-- Testing Query: Show the list of accountant Number along with their branch number.
-- SELECT employeeNum, employeeBranchNumber FROM Accountant JOIN Employee E ON Accountant.accountantNum = E.employeeNum



/**
  Section 1: Adding a missing column in the Maintenance table
  -- In phase 3: we missed a column named "maintenanceRequestorNum" inside the Maintenance table.
  -- "maintenanceRequestorNum" have to linked with "employeeNum" in the Employee table.
 */
-- Add a missing attribute in the Maintenance table
ALTER TABLE Maintenance
    ADD maintenanceRequestorNum int FOREIGN KEY (maintenanceRequestorNum) REFERENCES Employee(employeeNum)
GO;


-- Fill the new attribute with the first employee who carry out the maintenance
-- Assumes that the first employee in each maintenance is the requestor of that maintenance.
UPDATE Maintenance
SET Maintenance.maintenanceRequestorNum =
    (SELECT TOP 1 maintenanceEmployeeNum
    FROM Maintenance M JOIN MaintenanceEmployee ME
    ON M.maintenanceNumber = ME.employeeMaintenanceNumber
    WHERE M.maintenanceNumber = Maintenance.maintenanceNumber)
WHERE 1 = 1

-- Add a NOT NULL constraint to make it conform with the initial design.
ALTER TABLE Maintenance
ALTER COLUMN maintenanceRequestorNum int NOT NULL
GO;


/**
  Section 2: Remove excessive telephone numbers of customers who has more than 3 telephone numbers.
  -- This is to make sure that it conforms with the business requirements.
 */
DELETE FROM CustomerTelephone
WHERE customerTelephoneNumber NOT IN (
    SELECT TOP 3 K.customerTelephoneNumber
    FROM CustomerTelephone K
    WHERE K.telephoneCustomerNum = CustomerTelephone.telephoneCustomerNum AND EXISTS(
        SELECT telephoneCustomerNum, count(customerTelephoneNumber) as telCount
        FROM CustomerTelephone C
        WHERE C.telephoneCustomerNum = K.telephoneCustomerNum
        GROUP BY C.telephoneCustomerNum)
)
GO;
-- Testing Query: List the count of telephone numbers for each customer who has more than 3 phone numbers.
-- It is expected to have no result from the query below.
-- SELECT telephoneCustomerNum, count(customerTelephoneNumber) as telCount
--         FROM CustomerTelephone C
--         GROUP BY C.telephoneCustomerNum
--         HAVING count(C.customerTelephoneNumber) > 3



/**
  Section 3: Remove excessive telephone numbers of employees who has more than 3 telephone numbers.
  -- This is to make sure that it conforms with the business requirements.
 */
DELETE FROM EmployeeTelephone
WHERE employeeTelephoneNumber NOT IN (
    SELECT TOP 3 K.employeeTelephoneNumber
    FROM EmployeeTelephone K
    WHERE K.telephoneEmployeeNum = EmployeeTelephone.telephoneEmployeeNum AND EXISTS(
        SELECT telephoneEmployeeNum, count(employeeTelephoneNumber) as telCount
        FROM EmployeeTelephone C
        WHERE C.telephoneEmployeeNum = K.telephoneEmployeeNum
        GROUP BY C.telephoneEmployeeNum)
)
GO;
-- Testing Query: List the count of telephone numbers for each employee who has more than 3 phone numbers.
-- It is expected to have no result from the query below.
-- SELECT telephoneEmployeeNum, count(employeeTelephoneNumber) as telCount
--         FROM EmployeeTelephone E
--         GROUP BY E.telephoneEmployeeNum
--         HAVING count(E.employeeTelephoneNumber) > 3



/**
  Section 4: Update UtilityCost table in electricityUnitRate and waterUnitRate
  -- Change data type from decimal(6,4) to decimal(19,4) to prevent the overflow problem.
  -- The exist data about water and electricity price in the table will  also be updated
  */
ALTER TABLE Utilitycost
    ALTER COLUMN electricityUnitRate decimal(19, 4)
ALTER TABLE UtilityCost
    ALTER COLUMN waterUnitRate decimal(19, 4)
GO;


/**
  Section 5: Update PropertyDamage Table
  -- Drop NOT NULL constraint since the users will insert the property's damage detail before create a new customer billing
 */
ALTER TABLE PropertyDamage
    ALTER COLUMN propertyDamageBillingNumber int NULL
ALTER TABLE PropertyDamage
    ALTER COLUMN propertyDamageLineNumber int NULL



/**
  Section 6: Fixing mistakes in generating type of each Inventory Entry
  -- We had missed the type Withdraw 'W'.
 */
UPDATE dbo.InventoryEntry
SET inventoryEntryType = 'W'
WHERE entryNumber IN (SELECT TOP 54 PERCENT entryNumber FROM dbo.InventoryEntry ORDER BY NEWID());
GO;

-- If the supply number is null then it is not an entry for supply; therefore, there is no quantity.
UPDATE dbo.InventoryEntry
SET supplyUnitQuantity = NULL
WHERE entrySupplyNumber IS NULL;
GO;

UPDATE dbo.InventoryEntry
SET supplyUnitQuantity = (SELECT Cast(RAND()*(11-1)+1 as int))
WHERE entrySupplyNumber IS NULL AND entryReturningSupplyNumber IS NOT NULL
GO;

UPDATE InventoryEntry SET supplyUnitQuantity = supplyUnitQuantity * 2 WHERE inventoryEntryType = 'R'
GO;

-- SELECT entrySupplyNumber, SUM(supplyUnitQuantity)
-- FROM InventoryEntry
-- WHERE inventoryEntryType = 'W' GROUP BY entrySupplyNumber
--
-- -- Select to confirm that the data has changed properly.
-- SELECT inventoryEntryType, COUNT(entryNumber) AS recordCount
-- FROM InventoryEntry
-- GROUP BY inventoryEntryType;



/**
  Section 7: Fixing mistakes of Financial Transaction records that are associate with CustomerBilling
  are all being created or modified on 2017 only.
 */
UPDATE FinancialTransaction
SET financialTransactionTime = (SELECT TOP 1 DATEADD(MINUTE, 30, billingCreatedTime)
                            FROM CustomerBilling
                            WHERE billingFinancialTransactionNumber = financialTransactionNumber
                            ORDER BY billingCreatedTime DESC),
    financialTransactionCreatedTime = (SELECT DATEADD(MINUTE, -30, financialTransactionTime)),
    financialTransactionLastModifiedTime = financialTransactionCreatedTime
WHERE EXISTS(
    SELECT * FROM CustomerBilling WHERE billingFinancialTransactionNumber = financialTransactionNumber
);
GO;

-- Testing Query: List year and transaction count
-- SELECT YEAR(financialTransactionTime) year, COUNT(financialTransactionNumber) transactionCount
-- FROM FinancialTransaction
--     JOIN CustomerBilling CB ON FinancialTransaction.financialTransactionNumber = CB.billingFinancialTransactionNumber
--     GROUP BY YEAR(financialTransactionTime)



/**
  Section 8: Fixing mismatch PropertyInspection room and Rental room
 */
UPDATE PropertyInspection
SET propertyInspectionBranchNumber = (SELECT rentalBranchNumber FROM Rental WHERE rentalNumber = propertyInspectionRentalNumber),
    propertyInspectionRoomNumber = (SELECT rentalRoomNumber FROM Rental WHERE rentalNumber = propertyInspectionRentalNumber)
WHERE 1 = 1;
GO;

-- Testing Query: List the room and rental related to each maintenance
-- SELECT propertyInspectionNumber, propertyInspectionRoomNumber, rentalRoomNumber
-- FROM PropertyInspection JOIN Rental R2 ON PropertyInspection.propertyInspectionRentalNumber = R2.rentalNumber;



/**
  Section 9: Fixing maintenanceCategory labels
 */
UPDATE Maintenance
SET maintenanceCategory = 'Repairing'
WHERE maintenanceCategory IN ('Seafood', 'Beverages', 'Dairy', 'Shell fish', 'Produce', 'Meat', 'Cereals', 'Confections')
GO;

UPDATE Maintenance
SET maintenanceCategory = 'Replacing Parts'
WHERE maintenanceCategory IN ('Grain', 'Snails', 'Poultry', 'Building')
GO;

-- Testing Query: List all distinct maintenance categories
-- SELECT DISTINCT maintenanceCategory
-- FROM Maintenance
-- GROUP BY maintenanceCategory



/**
  Section 10: Update the rental ending time to be an estimate of the ending time of the last rental period
 */
UPDATE Rental
SET rentalEndingTime = CAST((
    SELECT MAX(RP.rentalPeriodEndingTime)
    FROM Rental R JOIN RentalPeriod RP ON R.rentalNumber = RP.rentalPeriodRentalNumber
    WHERE R.rentalNumber = Rental.rentalNumber) AS DATE)
WHERE 1 = 1;
GO;


/**
  Section 11: Adding Additional Objects in the room
 */
UPDATE RoomObject SET objectDateMovedIn = N'2015-08-30 16:53:12.660', roomObjectModelId = 20 WHERE objectNumber = 212
UPDATE RoomObject SET objectDateMovedIn = N'2015-08-30 16:53:12.660', roomObjectModelId = 11 WHERE objectNumber = 614
UPDATE RoomObject SET objectDateMovedIn = N'2015-08-30 16:53:12.660' WHERE objectNumber = 102
UPDATE RoomObject SET objectDateMovedIn = N'2015-08-30 16:53:12.660', roomObjectModelId = 17 WHERE objectNumber = 458
UPDATE RoomObject SET objectDateMovedIn = N'2015-08-30 16:53:12.660', roomObjectModelId = 9 WHERE objectNumber = 571
GO;





