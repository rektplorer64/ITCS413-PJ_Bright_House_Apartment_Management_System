
/**
  README: This file stores SQL COMMANDS that create STORED PROCEDURES that are used in database transactions
 */

-- RUN THIS COMMAND BEFORE GOING FURTHER!
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
 * -- P1: Insert the details of a new branch
 *
 * The bright house is the apartment business, which in the future may have a new branch to increase the revenue of the apartment.
 * This procedure is make for insert the data of a new branch when it occurs
 */
CREATE PROCEDURE spInsertNewBranch(
    @branchName           varchar(20),
    @branchBuildingNumber varchar(10),
    @branchStreetName     varchar(40),
    @branchSubDistrict    varchar(40),
    @branchDistrict       varchar(40),
    @branchProvince       varchar(40),
    @branchPostalCode     char(5),
    @branchEmail          varchar(320),
    @branchTelephone      varchar(10)
)
AS
BEGIN
    SET NOCOUNT ON
    BEGIN TRANSACTION
    BEGIN TRY

        -- Set branch number for a new branch
        DECLARE @branchNumber int
        SET @branchNumber = (
                            SELECT MAX(branchNumber)
                            FROM Branch) + 1
        IF @branchNumber IS NULL
            SET @branchNumber = 1

        -- Insert branch information
        INSERT INTO Branch
        VALUES (@branchNumber, @branchName, @branchBuildingNumber, @branchStreetName, @branchSubDistrict,
                @branchDistrict, @branchProvince, @branchPostalCode, @branchEmail)
        INSERT INTO BranchTelephone
        VALUES (@branchTelephone,@branchNumber)

        -- If successful, select the result to for the user.
        SELECT * FROM Branch WHERE branchNumber = @branchNumber;

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



/**
 * -- P2: Insert the details of a new Member of an Employee
 *
 * This store procedure creates a new record of a new employee who may be employed to
 * replace an existing one or to operate a new branch.
 */
CREATE PROCEDURE spInsertEmployee(
    @employeeFirstName       varchar(30),
    @employeeMiddleName      varchar(30),
    @employeeLastName        varchar(30),
    @employeeNickname        varchar(10),
    @employeeTelephoneNumber varchar(10),
    @role                    varchar(20),
    @employeeDOB             date,
    @employeeGender          char(1),
    @employeeBuildingNumber  varchar(10),
    @employeeStreetName      varchar(40),
    @employeeSubDistrict     varchar(40),
    @employeeDistrict        varchar(40),
    @employeeProvince        varchar(40),
    @employeePostalCode      char(5),
    @dailyWage               int,
    @employeeCitizenId       char(13),
    @employeeNationality     char(3),
    @employeeEmail           varchar(320),
    @employeeBranchNumber    int
)
AS
BEGIN
    SET NOCOUNT ON
    BEGIN TRANSACTION

    BEGIN TRY
        -- Set the employee number for a new employee
        DECLARE @employeeNumber int
        SET @employeeNumber = (SELECT MAX(employeeNum) FROM Employee) + 1

        IF @employeeNumber IS NULL
            SET @employeeNumber = 1

        -- Insert data of the new employee into the database
        INSERT INTO Employee
        VALUES (@employeeNumber, @employeeFirstName, @employeeMiddleName, @employeeLastName, @employeeNickname,
                @employeeDOB, @employeeGender, @employeeBuildingNumber, @employeeStreetName, @employeeSubDistrict,
                @employeeDistrict, @employeeProvince, @employeePostalCode, @dailyWage, @employeeCitizenId,
                @employeeNationality, @employeeEmail, @employeeBranchNumber)

        -- Insert the telephone number of a new Employee
        -- This means that they must have at least a telephone number
        INSERT INTO EmployeeTelephone
        VALUES (@employeeTelephoneNumber, @employeeNumber)

        -- Check employee's role before assign to the respective table
        IF @role = 'CleaningPersonnel'
            INSERT INTO CleaningPersonnel VALUES (@employeeNumber)
        ELSE
            IF @role = 'Manager'
                INSERT INTO Manager VALUES (@employeeNumber)
            ELSE
                IF @role = 'Accountant'
                    INSERT INTO Accountant VALUES (@employeeNumber)
        -- Other roles such as security does not have to be inserted to any of role-specific tables

        -- Working shift data need to separate due to the limitations of parameter
        -- each store procedure can execute per time

        -- If successful, Select the result to for the user.
        SELECT *
        FROM EmployeeDetailsView
        WHERE employeeNum = @employeeNumber;

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



/**
 * -- P2.1: Insert the employee working shift detail
 *
 * Due to the limitation of the amount of parameters each stored procedure can executed in a time, we separated the
 * insertion of a new employee and working shift apart.
 *
 * To put the detail of working shift of each employee, the user need to use the spInsertWorkingShift store procedure.
 */
CREATE PROCEDURE spInsertWorkingShift(
    @workingDay                 char(2),
    @workingShiftStartingHour   int,
    @workingShiftStartingMinute int,
    @workingShiftLengthHour     int,
    @employeeNum                int
)
AS
BEGIN
    SET NOCOUNT ON

    -- Insert working shift of each employee
    INSERT INTO EmployeeWorkingShift
    VALUES (@workingDay, @workingShiftStartingHour, @workingShiftStartingMinute, @workingShiftLengthHour, @employeeNum)

    -- If successful, Select the result to for the user.
    SELECT *
    FROM EmployeeWorkingShift WHERE workingShiftEmployeeNum = @employeeNum;
END
GO;



/**
 * -- P3: Insert the details of a new Customer
 *
 * Bright House apartment, like every business, need customer to stay and their information retained.
 * When a new customer comes to the Bright House apartment, an employee have to put a record of a new customers.
 * The employee will use the spInsertCustomer store procedure to insert data of a new customer.
 */
CREATE PROCEDURE spInsertCustomer(
    @customerFirstName       varchar(30),
    @customerMiddleName      varchar(30),
    @customerLastName        varchar(30),
    @customerNickname        varchar(10),
    @customerTelephoneNumber varchar(10),
    @customerDOB             date,
    @customerGender          char(1),
    @customerCountry         varchar(40),
    @customerCity            varchar(40),
    @customerProfession      varchar(40),
    @customerCitizenId       char(13),
    @customerNationality     varchar(40),
    @customerEmail           varchar(320)
)
AS
BEGIN
    SET NOCOUNT ON
    BEGIN TRANSACTION
    BEGIN TRY
        -- Set the customer number for a new customer
        DECLARE @customerNumber int
        SET @customerNumber = (
                              SELECT MAX(customerNum)
                              FROM Customer) + 1

        IF @customerNumber IS NULL
            SET @customerNumber = 1

        -- Insert the data of a new customer
        INSERT INTO Customer
        VALUES (@customerNumber, @customerFirstName, @customerMiddleName, @customerLastName, @customerNickname,
                @customerDOB, @customerGender, @customerCountry, @customerCity, @customerProfession,
                @customerCitizenId, @customerNationality, @customerEmail)

        -- Insert the customer telephone number
        INSERT INTO CustomerTelephone
        VALUES (@customerTelephoneNumber, @customerNumber)

        -- Customer passport and Visa data need to separate due to the limitations of
        -- parameter each store procedure can execute per time
        SELECT * FROM CustomerView WHERE customerNum = @customerNumber
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



/**
 * -- P3.1: Insert the details of customers Passport
 *
 * Due to the limitation of the amount of variable each stored procedure can executed in one time.
 * To put the detail of passport of each customers, user need to use spInsertCustomerPassport
 */
CREATE PROCEDURE spInsertCustomerPassport(
    @passportNumber char(9),
    @expirationDate date,
    @customerNum    int
)
AS
BEGIN
    SET NOCOUNT ON
    BEGIN TRANSACTION
    BEGIN TRY
        -- Check whether customer is a new or old customer
        IF @customerNum IS NULL
            THROW 50001, 'We cannot insert a new passport because a Customer Number is not provided!', 1

        -- Insert the customer's passport data
        INSERT INTO CustomerPassport
        VALUES (@passportNumber, @expirationDate, @customerNum)

        -- If successful, Select the result to for the user.
        SELECT *
        FROM (SELECT * FROM Customer WHERE customerNum = @customerNum) C
            JOIN CustomerPassport CP ON C.customerNum = CP.passportCustomerNum

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



/**
 * -- P3.2: Insert the details of customers Visa
 *
 * Some users may come from the country which does not require visa when they travels to thailand.
 * That's why the stored procedure of visa need to separated with the stored procedure of passport.
 * spInsertCustomerVisa is used to insert the detail of Visa into the database.
 */
CREATE PROCEDURE spInsertCustomerVisa(
    @visaNumber        varchar(13),
    @visaClass         varchar(6),
    @immigrationNumber int,
    @arrivalDate       date,
    @departureDate     date,
    @passportNumber    char(9)
)
AS
BEGIN
    SET NOCOUNT ON

    -- Insert the the customer's Visa data
    INSERT INTO CustomerVisa
    VALUES (@visaNumber, @visaClass, @immigrationNumber, @arrivalDate, @departureDate, @passportNumber)

    -- If successful, Select the result to for the user.
    SELECT *
    FROM CustomerVisa
    WHERE visaPassportNumber = @passportNumber AND visaNumber = @visaNumber

END
GO;



/**
 * -- P4: Insert the details of a new Room in a Branch
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



/**
 * -- P5: Insert the details of a new Customer Payment Billing line
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
 * -- P6: Insert the details of a new Room Utility
 *
 * In every period of rental, there will be a day that employee will record a water and electric meter of each room.
 * The record is use for calculated the utility cost of each room then the record of water and electricity cost
 * will be put in UtilityRecord table. To do so, spInsertUtilityCost is used.
 * Both Utility cost and customer billing will be created at the same time.
 */
CREATE PROCEDURE spInsertUtilityCost(
    @recordedTime         datetime,
    @electricityMeterUnit int,
    @waterMeterUnit       int,
    @roomUtilEmployeeNum  int,
    @roomUtilBranchNumber int,
    @roomUtilRoomNumber   int,
    @utilityTimeCreated   datetime,
    @utilityRentalNumber  int,
    @utilityStartingTime  datetime,
    @electricityUnitRate  decimal(19,4),
    @waterUnitRate        decimal(19,4),
    @discountAmount       decimal(19,4)
)
AS
BEGIN
    SET NOCOUNT ON
    BEGIN TRANSACTION
    BEGIN TRY
        -- Create the utility number for the new room utility record
        DECLARE @roomUtilNumber int
        SET @roomUtilNumber = (
                              SELECT MAX(roomUtilNumber)
                              FROM RoomUtilityRecord) + 1

        IF @roomUtilNumber IS NULL
            SET @roomUtilNumber = 1

        -- Create the utility number for the new room utility record
        DECLARE @utilityCostNumber int
        SET @utilityCostNumber = (SELECT MAX(utilityCostNumber) FROM UtilityCost) + 1

        IF @utilityCostNumber IS NULL
            SET @utilityCostNumber = 1


        DECLARE @lastWaterMeterUnit int
        DECLARE @lastElectricityMeterUnit int

        SELECT TOP 1 @lastElectricityMeterUnit = electricityMeterUnit, @lastWaterMeterUnit = waterMeterUnit
        FROM dbo.RoomUtilityRecord
        WHERE roomUtilRoomNumber = @roomUtilRoomNumber
          AND roomUtilBranchNumber = @roomUtilBranchNumber
        ORDER BY recordedTime DESC

        -- Calculate the electricity rate
        DECLARE @electricityFee decimal(19, 4)
        SET @electricityFee = CAST(((@electricityMeterUnit - @lastElectricityMeterUnit) * @electricityUnitRate) AS decimal(19, 4))

        -- Calculate the water rate
        DECLARE @waterFee decimal(19, 4)
        SET @waterFee = CAST((@waterMeterUnit - @lastWaterMeterUnit) * @waterUnitRate AS decimal(19, 4))

        -- FIXME: WE only want to add a new BillingLine...
        -- TODO: Use spGetLatestCustomerBillingByRentalNum and spInsertCustomerPaymentBillingLine to help in the insertion.
        -- Create new billing number for a new customer billing
        DECLARE @billingNumber int

        -- Get the latest Billing Number related to the Rental
        DECLARE @targetBillingTable table(targetBillingNum int)
        INSERT @targetBillingTable EXEC spGetLatestCustomerBillingByRentalNum @utilityRentalNumber, @utilityTimeCreated;

        SELECT @billingNumber = targetBillingNum FROM @targetBillingTable
        PRINT 'BillingNum:' + CAST(@billingNumber AS VARCHAR)

        -- Set the manager who supervises each customer billing of the branch
        DECLARE @managerNum int
        SET @managerNum = (
                          SELECT managerNum
                          FROM Manager
                                   JOIN Employee ON Employee.employeeNum = Manager.managerNum
                                   JOIN Branch ON Branch.branchNumber = Employee.employeeBranchNumber
                          WHERE Branch.branchNumber = @roomUtilBranchNumber)

       -- Retrieve the amount of utility cost
        DECLARE @customerBillingAmount decimal(19, 4)
        SET @customerBillingAmount = @electricityFee + @waterFee

        DECLARE @billingLineName varchar(40) = CONCAT('Utility Cost for Room ', CAST(@roomUtilRoomNumber AS VARCHAR))

        DECLARE @outputBillingNum int
        DECLARE @targetBillingLine int
        EXECUTE spInsertCustomerPaymentBillingLine @billingNumber,@billingLineName
            , @customerBillingAmount, 'Pending', @discountAmount,
            @roomUtilEmployeeNum, @outputBillingNum = @outputBillingNum OUTPUT, @outputBillingLineNum = @targetBillingLine OUTPUT;

        -- Insert the new room utility record data
        INSERT INTO RoomUtilityRecord
        VALUES (@roomUtilNumber, @recordedTime, @electricityMeterUnit, @waterMeterUnit,
                @roomUtilEmployeeNum, @roomUtilBranchNumber, @roomUtilRoomNumber)

        -- Insert a new utility cost data
        INSERT INTO UtilityCost
        VALUES (@utilityCostNumber, @electricityUnitRate, @waterUnitRate, @utilityTimeCreated,
                @utilityRentalNumber, @utilityStartingTime, @outputBillingNum, @targetBillingLine)

        SELECT *
        FROM CustomerBillingLine
            JOIN UtilityCost UC on CustomerBillingLine.customerBillingNumber = UC.utilityBillingNumber and CustomerBillingLine.customerBillingLineNumber = UC.utilityLineNumber
        WHERE utilityCostNumber = @utilityCostNumber AND customerBillingLineNumber = @targetBillingLine

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



/**
 * -- P7: Enter the details of a new Reservation
 *
 * spInsertReservation will be responsible for insert the data about reservation
 * The one who make a reservation can be an existing customer or a completely new customer who is never recorded.
 */
CREATE PROCEDURE spInsertReservation(
    @reservationCreatedTime datetime,
    @bookingFirstName       varchar(30),
    @bookingMiddleName      varchar(30),
    @bookingLastName        varchar(30),
    @bookingContact         varchar(10),
    @bookingGender          char(1),
    @expectedCheckInDate    date,
    @expectedCheckOutDate   date,
    @rentalType             char(1),
    @proposedRentalPrice    int,
    @proposedDepositAmount  int,
    @branchNumber           int,   -- TODO: get branchNumber from managerNumber?
    @roomNumber             int,
    @customerNumber         int,
    @managerNumber          int
)
AS
BEGIN
    SET NOCOUNT ON
    BEGIN TRANSACTION
    BEGIN TRY

        -- Retrieve a reservation number for a new reservation record
        DECLARE @reservationNumber int
        SET @reservationNumber = (
                                 SELECT MAX(reservationNumber)
                                 FROM Reservation) + 1

        IF @reservationNumber IS NULL
            SET @reservationNumber = 1

        -- Insert a new reservation record
        INSERT INTO Reservation
        VALUES (@reservationNumber, @reservationCreatedTime, @bookingFirstName, @bookingMiddleName,
                @bookingLastName, @bookingContact, @bookingGender, @expectedCheckInDate, @expectedCheckOutDate,
                @rentalType, @proposedRentalPrice, @proposedDepositAmount, @branchNumber, @customerNumber,
                @managerNumber);

        -- Insert the room that respective reservation reserved
        INSERT INTO ReservedRoom
        VALUES (@reservationNumber, @branchNumber, @roomNumber)

        SELECT * FROM dbo.Reservation WHERE reservationNumber = @reservationNumber;
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



/**
 * -- P8: Enter the details of a new Rental
 *
 * If the reservation haven't been cancelled, the customer will visit and rent a room in the apartment.
 * For the reservation data, spInsertRental will be used to insert a new rental data.
 * Each rental can have at most ONE room and TWO customers.
 */
CREATE PROCEDURE spInsertRental(
    @reservationNumber  int,
    @rentalType         char(1),
    @rentalDeposit      int,
    @rentalStartingTime datetime,
    @rentalEndingTime   datetime,
    @branchNumber       int,
    @roomNumber         int,
    @customer1Number    int,
    @customer2Number    int
)
AS
BEGIN
    SET NOCOUNT ON
    BEGIN TRANSACTION
    BEGIN TRY

        -- Create a new rental number for each rental record
        DECLARE @rentalNumber int
        SET @rentalNumber = (
                            SELECT MAX(rentalNumber)
                            FROM Rental) + 1

        IF @rentalNumber IS NULL
            SET @rentalNumber = 1

        -- Insert a new rental record
        INSERT INTO Rental
        VALUES (@rentalNumber, @rentalType, @rentalDeposit, @rentalStartingTime, @rentalEndingTime, @branchNumber,
                @roomNumber, @customer1Number, @reservationNumber);

        -- Mandatory: Add a customer into the rental
        INSERT INTO RentalCustomer
        VALUES (@rentalNumber, @customer1Number)

        -- Optional: Add another customer into the rental
        IF @customer2Number IS NOT NULL
            INSERT INTO RentalCustomer VALUES (@rentalNumber, @customer2Number)

        SELECT *
        FROM Rental WHERE rentalNumber = @rentalNumber;

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



/**
 * -- P9: Enter Subsequent Monthly Rental Period
 *
 * For the monthly rental customers, there will be subsequent rental period,
 * which spInsertSubsequentMonthlyRentalPeriod is used for insert the subsequent period detail.
 */
CREATE PROCEDURE spInsertSubsequentMonthlyRentalPeriod(
    @rentalNumber             int,
    @rentalPeriodStartingTime datetime,
    @rentalFee                decimal(19, 4)
) AS
BEGIN
    SET NOCOUNT ON
    BEGIN TRANSACTION
    BEGIN TRY

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
        SET @financialTransactionNumber =
                (
                SELECT MAX(financialTransactionNumber)
                FROM FinancialTransaction)

        --Insert a detail into item name
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

        -- To the next 30 days
        DECLARE @rentalPeriodEndingTime datetime
        SET @rentalPeriodEndingTime = DATEADD(DAY, 30, @rentalPeriodStartingTime)

        -- Insert the data into customer billing
        INSERT INTO CustomerBilling
        VALUES (@billingNumber, @billingDescription, @rentalPeriodStartingTime, @managerNum, @rentalNumber,
                @customerNum,
                @financialTransactionNumber)

        -- Insert the data into customer billing line
        INSERT INTO CustomerBillingLine
        VALUES (@billingNumber, @billingLineNumber, @customerBillingLineItemName, @customerBillingAmount,
                @customerBillingStatus, @rentalPeriodStartingTime, @customerBillingDiscountAmount, @managerNum,
                @rentalPeriodStartingTime)

        -- Retrieve a rental type
        DECLARE @periodCategory char(1)
        SET @periodCategory = 'M'

        -- Insert the subsequent rental period data
        INSERT INTO RentalPeriod
        VALUES (@rentalNumber, @rentalPeriodStartingTime, @rentalPeriodEndingTime, @periodCategory, @rentalFee,
                @billingNumber, @billingLineNumber)
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



/**
 * -- P10: Enter the data of a Requested Room Service
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



/**
 * -- P10.1: Get Current Rental by a Customer
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



/**
 * -- P10.2: Get Current CustomerBill by RentalNum
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



/**
 * -- P10.3: Get Latest BillingLine by BillingNumber
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



/**
 * -- P11: Enter the data of an Action done within a session of Requested Room Service
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



/**
 * -- P12: Add a Supply Withdrawal entry associated with Customer Service.
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



/**
 * -- P12.1: Retrieve the number of a returning supply so far given a branch.
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
      AND inventoryEntryType = 'R'

    IF @onHandTotal IS NULL
        SET @onHandTotal = 0

    -- Get the total of entry that is the result of a purchasing
    SELECT @onHandTotal = SUM(supplyUnitQuantity) + @onHandTotal
    FROM InventoryEntry
    WHERE entryReturningSupplyNumber = @supplyNumber
      AND entryBranchNumber = @branchId
      AND inventoryEntryType = 'P'

    IF @onHandTotal IS NULL
        SET @onHandTotal = 0

    -- Get the total amount of supply that is withdrawn
    SELECT @withdrawTotal = SUM(supplyUnitQuantity)
    FROM InventoryEntry
    WHERE entryReturningSupplyNumber = @supplyNumber
      AND entryBranchNumber = @branchId
      AND inventoryEntryType = 'W'

    IF @withdrawTotal IS NULL
        SET @withdrawTotal = 0

    SELECT @onHandTotal - @withdrawTotal AS onHandQuantity
END
GO;



/**
 * -- P12.2: Find Branch Number from a given employee number
 */
CREATE PROCEDURE spFindBranchOfGivenEmployeeNum(
    @employeeNum int
)
AS
BEGIN
    SELECT employeeBranchNumber FROM Employee WHERE employeeNum = @employeeNum
END
GO;



/**
 * -- P12.3: Find accountant number by a branch number
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



/**
 * -- P13: Enter the data of an Action done with a Routine Room Service
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



/**
 * -- P14: Add a new Supply from a purchasing to the inventory
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



/**
 * -- P15: List branches by a region
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



/**
 * -- P16: List employee by given details
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



/**
 * -- P17: For each Customer, List their rentals that are within the given time window.
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

    -- If the given ending of the time range is not given set it to the past 6 months.
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



/**
 * -- P18: Identify Customers by Rental Details
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



/**
 * -- P19: List expiring rentals in time range
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



/**
 * -- P20: List free rooms in a given time range
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
        SELECT dbo.funFormatFullRoomNumberString(roomBranchNumber, roomNumber) AS roomNumber, roomFloor, roomSize
        FROM Room R
             -- If the room is not exists in...
        WHERE NOT EXISTS(SELECT *
                         FROM Rental
                                  JOIN (
                                       SELECT *
                                       FROM Room
                                       WHERE roomNumber = R.roomNumber
                                         AND roomBranchNumber = R.roomBranchNumber) R2
                                       ON rentalRoomNumber = R2.roomNumber AND rentalBranchNumber = R2.roomBranchNumber
                              -- Where the rental is overlapping with the given time range
                         WHERE (rentalStartingTime <= @timeRangeEnd)
                           AND (rentalEndingTime >= @timeRangeStart))
        INTERSECT -- <~~ Both Conditions must be true
        SELECT dbo.funFormatFullRoomNumberString(roomBranchNumber, roomNumber) AS roomNumber, roomFloor, roomSize
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
                                       ON reservedRoomNumber = R2.roomNumber AND reserveBranchNumber = R2.roomBranchNumber
                              -- When the expected reservation time range is overlapping with the given time range
                         WHERE (expectedCheckInDate <= @timeRangeEnd)
                           AND (expectedCheckOutDate >= @timeRangeStart))
        ORDER BY roomNumber DESC

END
GO;



/**
 * -- P21: List all rentals in any branches associated with a given customer
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



/**
 * -- P22: For a given rental, List all room service details including its category, total actions done, starting time.
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



/**
 * -- P23: Insert the details of a Property Inspection
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



/**
 * -- P24: Insert the details of a Property Damage
 *
 * Every time the rental of each customer ends, a room inspection is required in order to check the property in a room,
 * which the detail will be recorded in PropertyInspection.
 *
 * The inspection will show the condition of each property in a room to insert the record of damage in PropertyDamage.
 * To do that, spInsertPropertyDamage is used.
 */
CREATE PROCEDURE spInsertPropertyDamage(
    @propertyInspectionNumber   int,
    @propertyDamageDescription  varchar(400),
    @propertyDamageSeverity     varchar(10),
    @objectNumber               int,
    @approvedTimestamp          datetime,
    @maintenanceRequestorEmpNum int,
    @maintenanceDescription     varchar(400),
    @maintenanceCategory        varchar(30),
    @billingEmployeeNum         int,
    @propertyDamageFee          decimal(19, 4),
    @feeDiscount                decimal(19, 4)
)
AS
BEGIN
    SET NOCOUNT ON
    BEGIN TRANSACTION
    BEGIN TRY

        -- Create a new property damage number for a new record
        DECLARE @propertyDamageNumber int
        SET @propertyDamageNumber = (
                                    SELECT MAX(propertyDamageNumber)
                                    FROM PropertyDamage) + 1

        -- Get the rental number from the inspection number
        DECLARE @rentalNumber int
        DECLARE @inspectorNumber int
        SELECT @rentalNumber = propertyInspectionRentalNumber, @inspectorNumber = propertyInspectionEmployeeNum
        FROM PropertyInspection
        WHERE propertyInspectionNumber = @propertyInspectionNumber

        -- Get branch number and room number from the rental number
        DECLARE @branchNumber int
        DECLARE @roomNumber int

        SELECT @branchNumber = rentalBranchNumber, @roomNumber = rentalRoomNumber FROM Rental WHERE Rental.RentalNumber = @rentalNumber


        -- Set the manager who supervises each customer billing
        DECLARE @managerNum int
        SET @managerNum = (
                          SELECT managerNum
                          FROM Manager
                                   JOIN Employee ON Employee.employeeNum = Manager.managerNum
                                   JOIN Branch ON Branch.branchNumber = Employee.employeeBranchNumber
                          WHERE Branch.branchNumber = @branchNumber)


        EXEC spInsertMaintenanceTask @maintenanceDescription, @maintenanceCategory, @maintenanceRequestorEmpNum,
             @objectNumber, NULL, NULL, NULL, NULL;
        DECLARE @maintenanceTaskId int = (
                                         SELECT MAX(maintenanceNumber)
                                         FROM Maintenance)

        -- Create new billing number for a new customer billing
        DECLARE @billingNumber int

        -- Create new billing line number for a new customer billing line
        DECLARE @billingLineNumber int
        IF @propertyDamageFee IS NOT NULL AND @propertyDamageFee > 0
            BEGIN
                -- Create a string for the billingLine
                DECLARE @objName varchar(32) = (
                                               SELECT (objectModelCategory + ' objId: ' + CAST(@objectNumber AS varchar))
                                               FROM RoomObject
                                                        JOIN RoomObjectModel ROM ON RoomObject.roomObjectModelId = ROM.objectModelId
                                               WHERE objectNumber = @objectNumber);

                -- Describe a billing as a "utility cost"
                DECLARE @billingLineName varchar(200) = 'Property Damage Fee for ' + @objName;


                -- Get billing number of the rental given the time.
                DECLARE @targetBillingTable table
                                            (
                                                targetBillingNum int
                                            );
                INSERT @targetBillingTable EXEC spGetLatestCustomerBillingByRentalNum @rentalNumber, @approvedTimestamp;

                SELECT @billingNumber = targetBillingNum FROM @targetBillingTable;
                SELECT targetBillingNum FROM @targetBillingTable;


                DECLARE @outputBillingNum int;

                EXEC spInsertCustomerPaymentBillingLine @billingNumber, @billingLineName
                    , @propertyDamageFee, 'Pending', @feeDiscount,
                     @billingEmployeeNum, @outputBillingNum = @outputBillingNum OUTPUT,
                     @outputBillingLineNum = @billingLineNumber OUTPUT;

                -- Retrieve the number of customer who need to pay the bill
                DECLARE @customerNum int
                SET @customerNum = (
                                   SELECT rentalBookingCustomerNum FROM Rental WHERE rentalNumber = @rentalNumber);

            END
        ELSE
            BEGIN
                SET @billingNumber = NULL
                SET @billingLineNumber = NULL
            END

        -- Insert a new property damage data
        INSERT INTO PropertyDamage
        VALUES (@propertyDamageNumber, @propertyDamageDescription, @propertyDamageSeverity,
                @propertyInspectionNumber, @billingNumber, @billingLineNumber, @objectNumber, @maintenanceTaskId,
                @managerNum, @approvedTimestamp, @inspectorNumber)

        SELECT *
        FROM PropertyDamage PD
                 JOIN (
                      SELECT *
                      FROM Maintenance
                      WHERE maintenanceNumber = @maintenanceTaskId) M
                      ON PD.propertyDamageMaintenanceNumber = M.maintenanceNumber
        WHERE PD.propertyDamageNumber = @propertyDamageNumber;
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



/**
 * -- P25: Insert the details of a Maintenance
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



/**
 * -- P26: Get Branch employee with max wage
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



/**
 * -- P27: Enter the data of a Routine Room Service
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




/**
 * -- P28: List the customer payment by a given rental number and customer name.
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

