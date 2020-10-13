
/**
  README: This file stores SQL COMMANDS that create TRIGGERS that are used in database transactions
 */

-- RUN THIS COMMAND BEFORE GOING FURTHER!
USE BRIGHT_HOUSE
GO;


/**
 * -- T1: Room Utility Operand Trigger
 *
 * After the record of water and electric meter and the utility cost have been put into the database,
 * it will trigger trRoomUtilityOperand. trUtilityOperand trigger is used for insert the record of RoomUtilityRecord
 * that responsible to the latest record of UtilityCost
 */
CREATE TRIGGER trAddRoomUtilityOperand
    ON UtilityCost
    AFTER INSERT
    AS
BEGIN
    SET NOCOUNT ON

    -- Retrieve the utility record number from the recently added record
    DECLARE @roomUtilNumber int

    -- We get the last room util that we have inserted along with a new utility cost.
    SET @roomUtilNumber = (
                          SELECT MAX(roomUtilNumber)
                          FROM roomUtilityRecord)

    -- Retrieve the utility cost number from the recently added record
    DECLARE @utilityCostNumber int
    SET @utilityCostNumber = (
                             SELECT MAX(utilityCostNumber)
                             FROM utilityCost)

    -- Insert data about the pair of utility record and utility cost
    INSERT INTO UtilityCostOperand
    VALUES (@utilityCostNumber, @roomUtilNumber)
END
GO;



/**
 * -- T2: Initial Rental Period Trigger
 *
 * After the detail of reservation has been put in, trInsertRentalPeriod trigger will begin to created an initial rental period for each rental.
 * For the customer who choose to rent daily, the initial period will be the only period of the customer rental.
 */
CREATE TRIGGER trAddRentalPeriod
    ON Rental
    AFTER INSERT
    AS
BEGIN
    SET NOCOUNT ON

    -- Retrieve the ID of the latest rental record
    DECLARE @rentalNumber int
    SET @rentalNumber = (SELECT MAX(rentalNumber) FROM Rental)

    -- Retrieve a type of the latest rental
    DECLARE @rentalType char(1)
    SET @rentalType = (SELECT TOP 1 rentalType FROM Rental ORDER BY rentalNumber DESC)

    -- Retrieve start rental day
    DECLARE @startDate datetime
    SET @startDate = (SELECT TOP 1 rentalStartingTime FROM Rental ORDER BY rentalNumber DESC)

    -- Check a rental type
    DECLARE @endDate datetime

    IF @rentalType = 'M'
        -- If rental type is month, the initial rental period will start from the start day to the next 30 days.
        SET @endDate = DATEADD(MONTH, 30, @startDate)
    ELSE
        -- If rental type is day, the rental period will start from the start day to the end day
        IF @rentalType = 'D'
            SET @endDate = (SELECT TOP 1 rentalEndingTime FROM Rental ORDER BY rentalNumber DESC)

    -- Insert the rental fee for each rental period
    DECLARE @rentalFee decimal(19, 4)

    IF @rentalType = 'M'
        -- If rental type is MONTHLY, rental fee will equal to the monthly rate
        SET @rentalFee = 6000
    ELSE
        -- If rental type is DAILY, rental fee will be a daily rate multiply by the amount of day customers rent
        IF @rentalType = 'D'
            SET @rentalFee = 500 * DATEDIFF(DAY, @startdate, @endDate)

    -- Create new billing number for a new customer billing
    DECLARE @billingNumber int
    SET @billingNumber = (
                         SELECT MAX(BillingNumber)
                         FROM customerBilling) + 1

    -- Create new billing line number for a new customer billing line
    DECLARE @billingLineNumber int
    SET @billingLineNumber = (
                             SELECT MAX(customerBillingLineNumber)
                             FROM customerBillingLine) + 1

    -- Describe a billing as a "utility cost"
    DECLARE @billingDescription varchar(200)
    SET @billingDescription = 'Rental Fee'

    -- Set the manager who supervises each customer billing
    DECLARE @managerNum int
    SET @managerNum = (
                      SELECT managerNum
                      FROM Manager
                               JOIN Employee ON Employee.employeeNum = Manager.managerNum
                               JOIN Branch ON Branch.branchNumber = Employee.employeeBranchNumber
                               JOIN Rental ON Rental.RentalBranchNumber = Branch.branchNumber
                      WHERE Rental.rentalNumber = @rentalNumber)

    -- Retrieve the number of customer who need to pay the bill
    DECLARE @customerNum int
    SET @customerNum = (
                       SELECT rentalBookingCustomerNum
                       FROM Rental
                       WHERE Rental.rentalNumber = @rentalNumber)

    -- Retrieve the financial transaction number this customer billing are
    DECLARE @financialTransactionNumber int
    SET @financialTransactionNumber = (SELECT MAX(financialTransactionNumber) FROM FinancialTransaction)

    -- Insert a detail into item name
    DECLARE @customerBillingLineItemName varchar(40)
    SET @customerBillingLineItemName = 'Rental Fee'

    -- Retrieve the  amount of utility cost
    DECLARE @customerBillingAmount decimal(19, 4)
    SET @customerBillingAmount = @rentalFee

    -- Update the status of billing
    DECLARE @customerBillingStatus varchar(10)
    SET @customerBillingStatus = 'Pending'

    -- Enter discount of utility cost
    DECLARE @customerBillingDiscountAmount decimal(19, 4)
    SET @customerBillingDiscountAmount = 0

    -- Insert the data into customer billing
    INSERT INTO CustomerBilling
    VALUES (@billingNumber, @billingDescription, @startDate, @managerNum, @rentalNumber, @customerNum,
            @financialTransactionNumber)

    -- Insert the data into customer billing line
    INSERT INTO CustomerBillingLine
    VALUES (@billingNumber, @billingLineNumber, @customerBillingLineItemName, @customerBillingAmount,
            @customerBillingStatus, @startDate, @customerBillingDiscountAmount, @managerNum,
            @startDate)

    -- Insert the initial rental period
    INSERT INTO RentalPeriod
    VALUES (@rentalNumber, @startDate, @endDate, @rentalType, @rentalFee,@billingNumber,@billingLineNumber)
    -- For the later round, there is a store procedure for the subsequent round
END