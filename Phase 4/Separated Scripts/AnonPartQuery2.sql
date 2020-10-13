USE BRIGHT_HOUSE
/**
 * -- 1: Insert the details of a new branch
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
    @branchEmail          varchar(320)
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

-- Add a new branch named Ouioui located in Bangkok, Klong Toei
EXEC spInsertNewBranch @branchName = 'Ouioui', @branchBuildingNumber = '846', @branchStreetName = 'Sukhumwit',
     @branchSubDistrict = 'Phra Khanong', @branchDistrict = 'Klong Toei', @branchProvince = 'Bangkok',
     @branchPostalCode = '10260', @branchEmail = NULL;



/**
 * -- 2: Insert the details of a new Member of an Employee
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
        FROM EmployeePositionSalaryView
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

EXEC spInsertEmployee @employeeFirstName = 'Apisara', @employeeMiddleName = NULL, @employeeLastName = 'Ngarmsri',
     @employeeNickname = 'Anne', @employeeTelephoneNumber='0874541672', @role='Manager', @employeeDOB='1978-2-5',
     @employeeGender='F', @employeeBuildingNumber='784', @employeeStreetName='Luang Phaeng',
     @employeeSubDistrict='Tub Yao', @employeeDistrict='Lat Krabang', @employeeProvince='Bangkok',
     @employeePostalCode='10520', @dailyWage=700, @employeeCitizenId='1107854687658', @employeeNationality='Tha',
     @employeeEmail='anne.13@gmail.com', @employeeBranchNumber=10

EXEC spInsertEmployee 'Tanawan', NULL, 'Ngarmsri',
     'Wan', '0625901002','Accountant','1978-2-5',
     'F', '784', 'Luang Phaeng',
     'Tub Yao', 'Lat Krabang', 'Bangkok',
     '10520', 700, '1107854687659', 'Tha',
     'wan.14@gmail.com', 10




/**
 * -- 2.1: Insert the employee working shift detail
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

EXEC spInsertWorkingShift @workingDay = 'MO', @workingShiftStartingHour = 8, @workingShiftStartingMinute = 30,
     @workingShiftLengthHour = 8, @employeeNum =51


/**
 * -- 3: Insert the details of a new Customer
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

EXEC spInsertcustomer @customerFirstName = 'Sophie', @customerMiddleName = NULL, @customerLastName = 'Ouioui',
     @customerNickname = 'Sophie', @customerTelephoneNumber='0625723493', @customerDOB='1996-2-12', @customerGender='F',
     @customerCountry='Austria', @customerCity='Vienna', @customerProfession='Pianist',
     @customerCitizenId='1107854687657', @customerNationality='Austria', @customerEmail='2ouioui@gmail.com'




/**
 * -- 3.1: Insert the details of customers Passport
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

EXEC spInsertCustomerPassport @passportNumber = '124575689', @expirationDate='2020-10-12', @customerNum = 51



/**
 * -- 3.2: Insert the details of customers Visa
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

EXEC spInsertCustomerVisa @visaNumber = '1112054352745', @visaClass = 'D', @immigrationNumber = 9675475,
     @arrivalDate = '2019-2-11', @departureDate = '2019-5-11', @passportNumber = 'C00817779';


/**
 * -- 6: Insert the details of a new Room Utility
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

        -- Create new billing number for a new customer billing
        DECLARE @billingNumber int

        -- Get the latest Billing Number related to the Rental
        DECLARE @targetBillingTable table(targetBillingNum int)
        INSERT @targetBillingTable EXEC spGetLatestCustomerBillingByRentalNum @utilityRentalNumber, @utilityTimeCreated;

--         DECLARE @targetBillingNum int
        SELECT @billingNumber = targetBillingNum FROM @targetBillingTable
        PRINT 'BillingNum:' + CAST(@billingNumber AS VARCHAR)

--         SET @billingNumber = (SELECT TOP 1 billingNumber
--                               FROM CustomerBilling JOIN Rental ON rentalNumber = billingRentalNumber
--                               WHERE rentalRoomNumber = 202 AND rentalNumber = 16
--                                 AND '2019-06-15' BETWEEN rentalStartingTime AND rentalEndingTime
--                               ORDER BY rentalStartingTime)



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

BEGIN TRANSACTION;
ROLLBACK;

EXEC spInsertUtilityCost @recordedTime = '2019-06-15 8:20:50.090', @electricityMeterUnit = 65, @waterMeterUnit = 59,
     @roomUtilEmployeeNum = 2, @roomUtilBranchNumber = 1, @roomUtilRoomNumber = 202,
     @utilityTimeCreated = '2019-06-15 8:40:50.090', @utilityRentalNumber = 18,
     @utilityStartingTime = '2019-06-09 01:17:40.650', @electricityUnitRate = 7, @waterunitRate = 1, @discountAmount = 0



/**
 * -- 7: Room Utility Operand Trigger
 *
 * After the record of water and electric meter and the utility cost have been put into the database,
 * it will trigger trRoomUtilityOperand. trUtilityOperand trigger is used for insert the record of RoomUtilityRecord
 * that responsible to the latest record of UtilityCost
 */
CREATE TRIGGER trRoomUtilityOperand
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
 * -- 8: Enter the details of a new Reservation
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
    @branchNumber           int,
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

EXEC spInsertReservation @reservationCreatedTime = '2020-4-25 8:20:50.090', @bookingFirstName = 'Brett',
     @bookingMiddleName = NULL, @bookingLastName = 'Eddy', @bookingContact = '00987457527', @bookingGender = 'M',
     @expectedCheckInDate = '2020-5-25', @expectedCheckOutDate = '2020-7-25', @rentalType = 'M',
     @proposedRentalPrice = 6000, @proposedDepositAmount = 3000, @branchNumber = 1, @roomNumber = 102,
     @customerNumber = 51, @managerNumber = 2


/**
 * -- 9: Enter the details of a new Rental
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

-- Customer #51 rents 2 months
EXEC spInsertRental @reservationNumber = 1901, @rentalType = 'M', @rentalDeposit = 3000,
     @rentalStartingTime = '2020-5-25 16:20:50.090', @rentalEndingTime = '2020-7-25 11:20:50.090', @branchNumber = 1,
     @roomNumber = 102, @customer1Number = 51, @customer2Number = NULL;



/**
 * -- 10: Initial Rental Period Trigger
 *
 * After the detail of reservation has been put in, trInsertRentalPeriod trigger will begin to created an initial rental period for each rental.
 * For the customer who choose to rent daily, the initial period will be the only period of the customer rental.
 */
CREATE TRIGGER trInsertRentalPeriod
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


/**
 * -- 11: Enter Subsequent Monthly Rental Period
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

EXEC spInsertSubsequentMonthlyRentalPeriod @rentalNumber = 1901, @rentalPeriodStartingTime = '2020-6-1 16:20:50.090', @rentalFee = 6000


/**
 * -- 44: Insert the details of a Property Damage
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

-- Add a property damage that have to be charged for the damage.
EXEC spInsertPropertyDamage 1149, 'A plant pot is broken into pieces.',
    'H', 102, '2019-03-11 05:51:53.560', 41,
    'Looks like the pot is broken and needed to be replaced!', 'Replacing the Unit', 42, 300, 0;

EXEC spInsertPropertyDamage 1149, 'The television is malfunctioning.',
    'M', 20, '2019-03-11 06:07:00.546', 41,
    'Looks like the television is broken and needed to be repaired!', 'Replacing Parts', 42, 15000, 0;

-- Add a property damage that do not have to be charged for the damage
EXEC spInsertPropertyDamage 1149, 'A plant pot is broken into pieces.',
    'H', 102, '2019-03-11 05:51:53.560', 41,
    'Looks like the pot is broken and needed to be replaced!', 'Replacing the Unit', 42, NULL, 0;



