/**
 * -- 13: Enter the data of a Requested Room Service
 *
 * Insert related information of a Service Request made by a customer.
 *
 * Please note that a customer service request will be inserted to the database before
 * the real service begins; therefore, supplies are not being considered in this procedure.
 */
CREATE PROCEDURE spInsertCustomerRequestedRoomService(
    @serviceType          char(1),
    @serviceDescription   varchar(300),
    @serviceStartTime     datetime,
    @cleaningPersonnelNum int,
    @customerNum          int,
    @billingName          varchar(40),
    @billingAmount        decimal(19, 4),
    @billingStatus        varchar(10),
    @discountAmount       decimal(19, 4),
    @employeeId           int
)
AS
BEGIN
    SET NOCOUNT ON

    BEGIN TRANSACTION
    BEGIN TRY
        -- Retrieve the ID number of the ongoing Rental that Associates with the customer DURING the time of the Service Request.
        DECLARE @currentRentalTable table(currentRental int)
        INSERT INTO @currentRentalTable EXEC spGetRentalDuringTimeByCustomerNum @customerNum, @serviceStartTime
        DECLARE @currentRentalNum int
        SELECT @currentRentalNum = currentRental FROM @currentRentalTable

        -- Calculate the STARTING TIME by 1 HOUR which is the default service duration.
        DECLARE @defaultServiceEndTime datetime
        SET @defaultServiceEndTime = DATEADD(HOUR, 1, @serviceStartTime)

        -- Get the last ID of the CustomerRoomService before making an insertion
        DECLARE @customerRoomServiceNum int
        SELECT @customerRoomServiceNum = (MAX(serviceNumber) + 1) FROM CustomerRoomService

        IF @customerRoomServiceNum IS NULL
            SET @customerRoomServiceNum = 1

        -- Insert the data into the main CustomerRoomService Table!
        INSERT INTO CustomerRoomService
        VALUES (@customerRoomServiceNum, @serviceType, @serviceDescription, @serviceStartTime,
                @defaultServiceEndTime, @currentRentalNum, @cleaningPersonnelNum)

        -- Get the latest Billing Number related to the Rental
        DECLARE @targetBillingTable table
                                    (
                                        targetBillingNum int
                                    )
        INSERT @targetBillingTable EXEC spGetLatestCustomerBillingByRentalNum @currentRentalNum, @serviceStartTime
        DECLARE @targetBillingNum int
        SELECT @targetBillingNum = targetBillingNum FROM @targetBillingTable

        IF @targetBillingNum IS NULL
            THROW 50001, 'Sorry, we cannot insert a new Customer Service Request for you because we cannot find a BillingNumber number within the rental period.', 1

        -- Current Time
        DECLARE @currentTime datetime
        SET @currentTime = CURRENT_TIMESTAMP;

        DECLARE @outputBillingNum int
        DECLARE @targetBillingLine int
        EXECUTE spInsertCustomerPaymentBillingLine @targetBillingNum,
            @billingName, @billingAmount, @billingStatus, @discountAmount,
            @employeeId, @outputBillingNum = @outputBillingNum OUTPUT, @outputBillingLineNum = @targetBillingLine OUTPUT;

        IF @outputBillingNum != @targetBillingNum
            THROW 50001, 'Mismatched target billing number caused by an error in billing line insertion', 1

        IF @targetBillingLine IS NULL
            THROW 50001, 'Sorry, we cannot insert a new Customer Service Request for you because we cannot find a BillingLine number within the rental period.', 1

        -- Insert the data into its sub-class which is RequestedRoomService
        INSERT INTO RequestedRoomService
        VALUES (@targetBillingNum, @targetBillingLine, @billingAmount, @customerRoomServiceNum)

        -- Insert the association between customer and request
        INSERT INTO CustomerServiceRequest
        VALUES (@customerNum, @targetBillingNum, @targetBillingLine, @customerRoomServiceNum, @currentTime)

        -- There is no Inventory insertion here since this is for the initialization of a Room Service.
        -- The Supply withdraw will be another process that will follow this procedure.

        SELECT * FROM RequestedRoomService
            JOIN CustomerServiceRequest CSR ON RequestedRoomService.requestedBillingNumber = CSR.customerRequestedBillingNumber
                                                   AND RequestedRoomService.requestedLineNumber = CSR.customerRequestedLineNumber
                                                   AND RequestedRoomService.requestedServiceNumber = CSR.customerRequestedServiceNumber
            JOIN CustomerRoomService CRS ON RequestedRoomService.requestedServiceNumber = CRS.serviceNumber
        WHERE serviceNumber = @customerRoomServiceNum

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

EXEC spInsertCustomerRequestedRoomService 'R', 'Cleaning Room for a customer', '2019-11-15 11:38:58.380', 1, 10,
     'Room Cleaning Service', 200, 'PA', 0, 1;
GO;



/**
 * -- 13.1: Get Current Rental by a Customer
 *
 * Retrieve the Rental associates with a customer during a given time.
 */
CREATE PROCEDURE spGetRentalDuringTimeByCustomerNum(
    @customerNum int,
    @time        datetime
)
AS
BEGIN

    SET NOCOUNT ON

    IF @time IS NULL
        SET @time = CURRENT_TIMESTAMP

    SELECT rentalNumber
    FROM Rental
             JOIN (
                  SELECT *
                  FROM RentalCustomer
                  WHERE rentalCustomerNum = @customerNum)
        AS RC ON Rental.rentalNumber = RC.rentalCustomerRentalNumber AND
                 CAST(@time AS date) BETWEEN CAST(rentalStartingTime AS date) AND CAST(rentalEndingTime AS date)
END
GO;

EXEC spGetRentalDuringTimeByCustomerNum 10, '2019-11-15 11:38:58.380'
GO;



/**
 * -- 13.2: Get Current CustomerBill by RentalNum
 *
 * Retrieve the Latest CustomerBilling using a given Rental Number with in a specific time.
 */
CREATE PROCEDURE spGetLatestCustomerBillingByRentalNum(
    @rentalNum int,
    @time      datetime
)
AS
BEGIN
    SET NOCOUNT ON

    IF @time IS NULL
        SET @time = CURRENT_TIMESTAMP

    -- Try to get the on-going rental period during the given time
    -- We use it to get the latest
    SELECT TOP 1 rentalPeriodBillingNumber
    FROM (
         SELECT rentalNumber
         FROM Rental
         WHERE rentalNumber = @rentalNum) AS R
             JOIN RentalPeriod P ON P.rentalPeriodRentalNumber = R.rentalNumber
    WHERE @time >= rentalPeriodStartingTime
      AND @time <= rentalPeriodEndingTime
    ORDER BY rentalPeriodStartingTime

END
GO;

EXEC spGetLatestCustomerBillingByRentalNum 1323, '2019-11-15 11:38:58.380'
GO;



/**
 * -- 13.3: Get Latest BillingLine by BillingNumber
 *
 * Retrieve the Latest BillingLine number from a given BillingNumber
 */
CREATE PROCEDURE spGetLatestBillingLineByBillingNum(
    @billingNum int
)
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @maxBillingLineNumber int

    -- Get the latest billingLineNum of a given billing line
    SELECT @maxBillingLineNumber = MAX(customerBillingLineNumber)
    FROM (
         SELECT billingNumber FROM CustomerBilling WHERE billingNumber = @billingNum) B
             JOIN CustomerBillingLine CBL ON B.billingNumber = CBL.customerBillingNumber
    GROUP BY billingNumber

    IF @maxBillingLineNumber IS NULL
        SET @maxBillingLineNumber = 1

    SELECT @maxBillingLineNumber AS LastBillingLineNumber;
END
GO;

EXEC spGetLatestBillingLineByBillingNum 583
GO;



/**
 * -- 14: Enter the data of an Action done within a session of Requested Room Service
 *
 * Enter the actions of the data done within a Requested Room Service
 */
CREATE PROCEDURE spInsertActionDoneInRequestedRoomService(
    @requestedBillingNumber int,
    @requestedLineNumber    int,
    @requestedServiceNumber int,
    @serviceActionNumber    int,
    @serviceActionName      varchar(50)
)
AS
BEGIN
    SET NOCOUNT ON

    BEGIN TRANSACTION
        BEGIN TRY
            -- If the Action number is not provided, but the action name is provided instead.
            IF @serviceActionNumber IS NULL AND @serviceActionName IS NOT NULL
                -- Select for the name from the database
                SELECT @serviceActionNumber = roomServiceNumber
                FROM RoomServiceAction
                WHERE serviceName = @serviceActionName

            -- Insert the data into the table
            INSERT INTO RequestedPerformedRoomServiceAction
            VALUES (@requestedBillingNumber, @requestedLineNumber, @requestedServiceNumber, @serviceActionNumber)

            -- Selected the result preview
            SELECT performRequestedBillingNumber AS billingNum,
                   performRequestedLineNumber    AS billingLineNumber,
                   performRequestedServiceNumber AS serviceNum,
                   performRequestedServiceNumber AS serviceActionCode,
                   serviceName                   AS serviceActionName
            FROM RequestedPerformedRoomServiceAction
                     JOIN RoomServiceAction ON RequestedPerformedRoomServiceAction.performRequestedRoomServiceNumber =
                                               RoomServiceAction.roomServiceNumber
                     JOIN RequestedRoomService RRS
                          ON RequestedPerformedRoomServiceAction.performRequestedBillingNumber =
                             RRS.requestedBillingNumber
                              AND
                             RequestedPerformedRoomServiceAction.performRequestedLineNumber = RRS.requestedLineNumber
                              AND RequestedPerformedRoomServiceAction.performRequestedServiceNumber =
                                  RRS.requestedServiceNumber
            WHERE requestedBillingNumber = @requestedBillingNumber
              AND requestedLineNumber = @requestedLineNumber
              AND requestedServiceNumber = @requestedServiceNumber
              AND performRequestedRoomServiceNumber = @serviceActionNumber
            ORDER BY performRequestedBillingNumber, performRequestedLineNumber;

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

EXEC spInsertActionDoneInRequestedRoomService 1, 836, 14343, NULL, 'Floor sweeping';
GO;



/**
 * -- 15: Add a Supply Withdrawal entry associated with Customer Service.
 *
 * Record a supply associate entry with a customer service
 */
CREATE PROCEDURE spInsertWithdrawalEntryRelatedToCustomerService(
    @returningSupplyNumber int,
    @withdrawalDescription nvarchar(50),
    @supplyUnitQuantity    int,
    @serviceNumber         int,
    @employeeA             int,
    @employeeB             int,
    @employeeC             int,
    @employeeD             int,
    @employeeE             int
)
AS
BEGIN
    SET NOCOUNT ON

    BEGIN TRY
        BEGIN TRANSACTION
            -- Get the last ID of the inventory entry table
            DECLARE @lastInventoryEntryId int
            SELECT @lastInventoryEntryId = (MAX(entryNumber) + 1) FROM InventoryEntry

            IF @lastInventoryEntryId IS NULL
                SET @lastInventoryEntryId = 1

            -- Try to get a branch number
            DECLARE @branchIdTable table(branchId int)
            INSERT INTO @branchIdTable EXEC spFindBranchOfGivenEmployeeNum @employeeA
            DECLARE @branchId int
            SELECT @branchId = branchId FROM @branchIdTable

            -- Check if the supply can be retrieved or not by using conditional
            -- checking for the total quantity of the returning supply left.
            DECLARE @remainingSupplyTable table(numberLeft int)
            INSERT INTO @remainingSupplyTable EXEC spIdentifyReturningSupplyOnHandQuantity @returningSupplyNumber,
                                                   @branchId

            -- Get the number of supply left
            DECLARE @numberOfSupplyLeft int
            SELECT @numberOfSupplyLeft = numberLeft FROM @remainingSupplyTable

            -- Get the number of the accountant
            DECLARE @accountantNumTable table(accountantNum int)
            INSERT INTO @accountantNumTable EXEC spFindAccountantByBranchNum @branchId
            DECLARE @accountantNumber int
            SELECT @accountantNumber = accountantNum FROM @accountantNumTable

            IF @numberOfSupplyLeft IS NULL
                RAISERROR ('There is no record of this supply!', 16, 1)
            ELSE
                -- Trying to insert a new item into an inventory entry
                INSERT INTO InventoryEntry
                VALUES (@lastInventoryEntryId, @withdrawalDescription, @supplyUnitQuantity, CURRENT_TIMESTAMP, 'W',
                        NULL, @returningSupplyNumber, NULL, @accountantNumber, @serviceNumber, @branchId)

            -- There must be at least 1 recorder.
            INSERT INTO InventoryEntryRecorder VALUES (@lastInventoryEntryId, @employeeA, CURRENT_TIMESTAMP)

            IF @employeeB IS NOT NULL
                INSERT INTO InventoryEntryRecorder VALUES (@lastInventoryEntryId, @employeeB, CURRENT_TIMESTAMP)

            IF @employeeC IS NOT NULL
                INSERT INTO InventoryEntryRecorder VALUES (@lastInventoryEntryId, @employeeC, CURRENT_TIMESTAMP)

            IF @employeeD IS NOT NULL
                INSERT INTO InventoryEntryRecorder VALUES (@lastInventoryEntryId, @employeeD, CURRENT_TIMESTAMP)

            IF @employeeE IS NOT NULL
                INSERT INTO InventoryEntryRecorder VALUES (@lastInventoryEntryId, @employeeE, CURRENT_TIMESTAMP)

            -- Select the result to display
            SELECT *
            FROM InventoryEntry
            WHERE entryNumber = @lastInventoryEntryId

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

EXEC spInsertWithdrawalEntryRelatedToCustomerService
     8, 'Cleaning Supply', 5, 1, 41, NULL, NULL, NULL, NULL;
GO;



/**
 * -- 15.1: Retrieve the number of a returning supply so far given a branch.
 *
 * Identify the number of given returning supply on hand in a branch
 */
CREATE PROCEDURE spIdentifyReturningSupplyOnHandQuantity(
    @supplyNumber int,
    @branchId     int
)
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @onHandTotal int
    DECLARE @withdrawTotal int

    -- Get the number of supply that are returned to the inventory
    SELECT @onHandTotal = SUM(supplyUnitQuantity)
    FROM InventoryEntry
    WHERE entryReturningSupplyNumber = @supplyNumber
      AND entryBranchNumber = @branchId

    -- Get the total of entry that contains the export/withdrawal of the supply
    SELECT @onHandTotal = SUM(supplyUnitQuantity) + @onHandTotal
    FROM InventoryEntry
    WHERE entrySupplyNumber = @supplyNumber
      AND entryBranchNumber = @branchId
      AND InventoryEntry.entryNumber IN (
                                        SELECT purchasingLineInventoryEntryNumber
                                        FROM PurchasingLine
                                        WHERE entryBranchNumber = @branchId)

    -- Get the total amount of supply that is withdrawn
    SELECT @withdrawTotal = SUM(supplyUnitQuantity)
    FROM InventoryEntry
    WHERE entrySupplyNumber = @supplyNumber
      AND entryBranchNumber = @branchId
      AND InventoryEntry.entryAccountantNumber IS NOT NULL

    SELECT @onHandTotal - @withdrawTotal
END
GO;



/**
 * -- 15.2: Find Branch Number from a given employee number
 */
CREATE PROCEDURE spFindBranchOfGivenEmployeeNum(
    @employeeNum int
)
AS
BEGIN
    SELECT employeeBranchNumber FROM Employee WHERE employeeNum = @employeeNum
END
GO;

EXEC spFindBranchOfGivenEmployeeNum 41;
GO;



/**
 * -- 15.3: Find accountant number by a branch number
 */
CREATE PROCEDURE spFindAccountantByBranchNum(
    @branchNum int
)
AS
BEGIN
    DECLARE @employeeNum int

    SELECT @employeeNum = employeeNum
    FROM Employee
             JOIN Accountant A
                  ON Employee.employeeNum = A.accountantNum
    WHERE employeeBranchNumber = @branchNum

    IF @employeeNum IS NULL
        THROW 50003, 'This branch has no Accountant!', 1
    ELSE
        SELECT @employeeNum AS accountantEmplNum
END
GO;

EXEC spFindAccountantByBranchNum 8;
GO;



/**
 * -- 16: Enter the data of an Action done with a Routine Room Service
 *
 * After a routine room cleaning service action/sub-task has been carried out by a cleaning personnel,
 * the personnel will have to record them similar to checklist for cleaning.
 */
CREATE PROCEDURE spInsertRoutineRoomServiceAction(
    @routineRoomServiceNum int,
    @serviceActionNumber   int
)
AS
BEGIN
    SET NOCOUNT ON

    BEGIN TRANSACTION
        BEGIN TRY
            -- If the given serviceActionNumber doesn't exist in the RoomServiceAction table
            IF NOT EXISTS(
                    SELECT roomServiceNumber FROM RoomServiceAction WHERE roomServiceNumber = @serviceActionNumber)
                THROW 50001, 'Invalid Service Action ID', 1;

            -- If the given routineRoomServiceNumber doesn't exist in the RoutineRoomService table
            IF NOT EXISTS(SELECT routineServiceNumber
                          FROM RoutineRoomService
                          WHERE routineServiceNumber = @routineRoomServiceNum)
                THROW 50002, 'Invalid Routine Room Service ID', 1;

            INSERT INTO RoutinePerformedRoomServiceAction
            VALUES (@routineRoomServiceNum, @serviceActionNumber)
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

EXEC spInsertRoutineRoomServiceAction 1, 6;
GO;



/**
 * -- 17: Add a new Supply from a purchasing to the inventory
 *
 * After employees who are assigned to a purchasing returned with items required,
 * the subsequent process of recording the amount of each supply will begin. To do so, table InventoryEntry is used.
 *
 * Each supply type will be recorded based on its purchasing line that is contained in a purchasing instances.
 * Moreover, the purchasing-responsible employees will have to be the recorders of a new inventory entry record.
 */
CREATE PROCEDURE spInsertNewSupplyFromPurchasingToInventory(
    @purchasingNum     int,
    @purchasingLineNum int,
    @entryDescription  nvarchar(100),
    @accountantNum     int
)
AS
BEGIN
    SET NOCOUNT ON

    BEGIN TRANSACTION
        BEGIN TRY
            IF NOT EXISTS(SELECT *
                          FROM PurchasingLine
                          WHERE linePurchasingNumber = @purchasingNum AND purchasingLineNumber = @purchasingLineNum)
                THROW 50001, 'There is no purchasing line record for the given purchasing No. & line No.', 1

            IF NOT EXISTS(SELECT * FROM Purchasing WHERE purchasingNumber = @purchasingLineNum AND purchasingType = 'R')
                THROW 50001, 'The specified purchasing is not the type of Resupplying (R)', 1

            DECLARE @quantity int
            DECLARE @supplyNum int
            DECLARE @requestorId int

            -- Select the target purchasing line by using its purchasing line and line number
            -- We will retrieve information required for the insertion of a new Purchasing Deposit.
            SELECT @quantity = purchasingLineQuantity,
                   @supplyNum = purchasingLineSupplyNumber,
                   @requestorId = purchasingRequestorEmployeeNum
            FROM Purchasing
                     JOIN PurchasingLine ON Purchasing.purchasingNumber = PurchasingLine.linePurchasingNumber
            WHERE purchasingNumber = @purchasingNum
              AND purchasingLineNumber = @purchasingLineNum

            -- Assumes that the destination inventory is at the branch of the purchasing requestor
            DECLARE @branchTable table(branchNum int)
            INSERT INTO @branchTable EXEC spFindBranchOfGivenEmployeeNum @requestorId
            DECLARE @branch int
            SELECT @branch = branchNum FROM @branchTable

            -- Get the ID to insert
            DECLARE @maxEntryId int
            SELECT @maxEntryId = (entryNumber + 1) FROM InventoryEntry

            IF @maxEntryId IS NULL
                SET @maxEntryId = 1

            -- Try inserting a new inventory entry
            INSERT INTO InventoryEntry
            VALUES (@maxEntryId, @entryDescription, @quantity, CURRENT_TIMESTAMP, 'P', @supplyNum, NULL, NULL,
                    @accountantNum, NULL, @branch)

            -- Try getting inserting purchasers to inventory recorder!
            DECLARE @purEmployees table(employeeNum int)
            DECLARE @employeeId int

            -- Retrieve purchasing employees from a give purchasingNumber
            INSERT INTO @purEmployees
                SELECT purchasingEmployeeNum
                FROM PurchasingEmployee
                WHERE purchasingEmployeePurchasingNumber = @purchasingNum;

            -- For each purchasing employee, Insert them into the Inventory Recorder table
            WHILE EXISTS(SELECT * FROM @purEmployees)
                BEGIN
                    SELECT TOP 1 @employeeId = employeeNum FROM @purEmployees
                    INSERT INTO InventoryEntryRecorder VALUES (@maxEntryId, @employeeId, CURRENT_TIMESTAMP)
                    DELETE @purEmployees WHERE employeeNum = @employeeId
                END

            -- Select the newly inserted inventory entry
            SELECT * FROM InventoryEntry WHERE entryNumber = @maxEntryId

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

EXEC spInsertNewSupplyFromPurchasingToInventory 2, 1244, 'Receiving supply from a vendor', 43;
GO;

-- SELECT IER.*
-- FROM InventoryEntry IE JOIN InventoryEntryRecorder IER ON IE.entryNumber = IER.recordInventoryEntryNumber
-- WHERE entryNumber = 50002;

-- SELECT PE.* FROM Purchasing P JOIN PurchasingEmployee PE
--     ON P.purchasingNumber = PE.purchasingEmployeePurchasingNumber WHERE purchasingNumber = 2;
--
-- SELECT *
-- FROM Purchasing JOIN PurchasingLine PL ON Purchasing.purchasingNumber = PL.linePurchasingNumber
-- WHERE purchasingNumber = 2;


/**
 * -- 45: Insert the details of a Maintenance
 *
 * In order for a maintenance task to start, it need to be recorded using this procedure.
 */
CREATE PROCEDURE spInsertMaintenanceTask(
    @description  varchar(400),
    @category     varchar(30),
    @requestorNum int,
    @roomObj1     int,
    @roomObj2     int,
    @roomObj3     int,
    @roomObj4     int,
    @roomObj5     int
)
AS
BEGIN
    SET NOCOUNT ON
    BEGIN TRANSACTION
    BEGIN TRY
        -- Select the max ID of the maintenance
        DECLARE @maxMaintenanceNum int
        SELECT @maxMaintenanceNum = MAX(maintenanceNumber + 1) FROM Maintenance

        IF @maxMaintenanceNum IS NULL
            SET @maxMaintenanceNum = 1

        -- Insert it to the maintenance table
        INSERT INTO Maintenance
        VALUES (@maxMaintenanceNum, CURRENT_TIMESTAMP, 'Not Started', NULL, NULL, CURRENT_TIMESTAMP, @description,
                @category, @requestorNum)

        IF @roomObj1 IS NOT NULL
            INSERT INTO MaintenanceRoomObject VALUES (@roomObj1, @maxMaintenanceNum)
        ELSE
            THROW 50001, 'RoomObject ID 1 is not provided!', 1

        IF @roomObj2 IS NOT NULL
            INSERT INTO MaintenanceRoomObject VALUES (@roomObj2, @maxMaintenanceNum)

        IF @roomObj3 IS NOT NULL
            INSERT INTO MaintenanceRoomObject VALUES (@roomObj3, @maxMaintenanceNum)

        IF @roomObj4 IS NOT NULL
            INSERT INTO MaintenanceRoomObject VALUES (@roomObj4, @maxMaintenanceNum)

        IF @roomObj5 IS NOT NULL
            INSERT INTO MaintenanceRoomObject VALUES (@roomObj5, @maxMaintenanceNum)

        SELECT * FROM Maintenance WHERE maintenanceNumber = @maxMaintenanceNum

        SELECT MRO.*, RO.*
        FROM Maintenance
                 JOIN MaintenanceRoomObject MRO ON Maintenance.maintenanceNumber = MRO.roomMaintenanceNumber
                 JOIN RoomObject RO ON MRO.maintenanceRoomObjectNumber = RO.objectNumber
        WHERE maintenanceNumber = @maxMaintenanceNum
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

EXEC spInsertMaintenanceTask 'Fix these objects', 'Building', 1, 1, 2, 3, NULL, NULL;
GO;



/**
 * -- 47: Get Branch employee with max wage
 *
 * Identify the employee who has the highest wage payment by a given branch.
 */
CREATE PROCEDURE spGetBranchEmployeeWithMaxWage(
    @branchNum int
)
AS
BEGIN
    SET NOCOUNT ON

    -- Get the Manager Number of the employee
    DECLARE @managerNum int
    SELECT @managerNum = managerNum
    FROM Manager
             JOIN Employee E2 ON Manager.managerNum = E2.employeeNum
    WHERE employeeBranchNumber = @branchNum

    -- Retrieve the highest amount of money paid the manager
    DECLARE @maxWageBranchPayment float
    SELECT @maxWageBranchPayment = MAX(financialTransactionAmount)
    FROM EmployeeWagePayment
             JOIN FinancialTransaction FT
                  ON EmployeeWagePayment.wagePaymentFinancialTransactionNumber = FT.financialTransactionNumber
    WHERE wagePaymentManagerNum = @managerNum

    -- Get the ID of the employee in the transaction with maximum payment
    DECLARE @employeeNum int
    SELECT @employeeNum = wagePaymentEmployeeNum
    FROM EmployeeWagePayment
             JOIN FinancialTransaction FT
                  ON EmployeeWagePayment.wagePaymentFinancialTransactionNumber = FT.financialTransactionNumber
    WHERE financialTransactionAmount = @maxWageBranchPayment


    -- Return a further details of the employee
    SELECT employeeNum,
           dbo.funFormatFullNameString(employeeFirstName, employeeMiddleName, employeeLastName) AS fullName,
           financialTransactionAmount,
           employeeNickname,
           employeeGender
    FROM Employee AS a
             JOIN EmployeeWagePayment EWP ON a.employeeNum = EWP.wagePaymentEmployeeNum
             JOIN FinancialTransaction F ON EWP.wagePaymentFinancialTransactionNumber = F.financialTransactionNumber
    WHERE employeeNum = @employeeNum
      AND financialTransactionAmount = @maxWageBranchPayment

END
GO;

EXEC spGetBranchEmployeeWithMaxWage @branchNum = 2;
GO;



/**
 * -- 48: Enter the data of a Routine Room Service
 *
 * Insert related information of a Service Request done routinely by a cleaning personnel.
 *
 * Please note that the request will be inserted to the database before
 * the real service begins; therefore, supplies are not being considered in this procedure.
 */
CREATE PROCEDURE spInsertRoutineRoomService(
    @serviceType          char(1),
    @serviceDescription   varchar(300),
    @serviceStartTime     datetime,
    @cleaningPersonnelNum int,
    @currentRentalNum     int
)
AS
BEGIN
    SET NOCOUNT ON

    BEGIN TRANSACTION
    BEGIN TRY
        -- Calculate the STARTING TIME by 1 HOUR which is the default service duration.
        DECLARE @defaultServiceEndTime datetime
        SET @defaultServiceEndTime = DATEADD(HOUR, 1, @serviceStartTime)

        -- Get the last ID of the CustomerRoomService before making an insertion
        DECLARE @customerRoomServiceNum int
        SELECT @customerRoomServiceNum = (MAX(serviceNumber) + 1) FROM CustomerRoomService

        IF @customerRoomServiceNum IS NULL
            SET @customerRoomServiceNum = 1

        -- Insert the data into the main CustomerRoomService Table!
        INSERT INTO CustomerRoomService
        VALUES (@customerRoomServiceNum, @serviceType, @serviceDescription, @serviceStartTime,
                @defaultServiceEndTime, @currentRentalNum, @cleaningPersonnelNum)

        -- Current Time
        DECLARE @currentTime datetime
        SET @currentTime = CURRENT_TIMESTAMP

        -- Insert the data into its sub-class which is RequestedRoomService
        INSERT INTO RoutineRoomService
        VALUES (@currentTime, @customerRoomServiceNum)

        -- There is no Inventory insertion here since this is for the initialization of a Room Service.
        -- The Supply withdraw will be another process that will follow this procedure.
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

EXEC spInsertRoutineRoomService 'R', 'Cleaning Room for a customer', '2019-11-15 11:38:58.380', 1, 10
GO;



/**
 * -- 49: List the customer payment by a given rental number and customer name.
 */
CREATE PROCEDURE spListCustomerPaymentByRentalCustomer(
    @rentalNumber int,
    @customerNum  int
)
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @queryRentalNumber varchar(20)
    DECLARE @queryCustomerNum varchar(20)

    IF @rentalNumber IS NULL
        SET @queryRentalNumber = '%'
    ELSE
        SET @queryRentalNumber = CAST(@rentalNumber AS varchar)

    IF @customerNum IS NULL
        SET @queryCustomerNum = '%'
    ELSE
        SET @queryCustomerNum = CAST(@customerNum AS varchar)

    SELECT rentalNumber,
           billingNumber,
           billingDescription,
           billingCreatedTime,
           SUM(customerBillingAmount)         AS totalBilledAmount,
           SUM(customerBillingDiscountAmount) AS totalDiscountAmount,
           SUM(financialTransactionAmount)    AS actualTransactedAmount
    FROM (
         SELECT *
         FROM Rental
         WHERE rentalNumber LIKE @queryRentalNumber) R
             JOIN (
                  SELECT *
                  FROM RentalCustomer
                  WHERE rentalCustomerNum LIKE @queryCustomerNum) RC ON R.rentalNumber = RC.rentalCustomerRentalNumber
             JOIN CustomerBilling CB ON R.rentalNumber = CB.billingRentalNumber
             JOIN CustomerBillingLine CBL ON CB.billingNumber = CBL.customerBillingNumber
             LEFT JOIN FinancialTransaction FT ON CB.billingFinancialTransactionNumber = FT.financialTransactionNumber
    GROUP BY rentalNumber, billingNumber, billingDescription, billingCreatedTime
END
GO;

EXEC spListCustomerPaymentByRentalCustomer 145, NULL
GO;
