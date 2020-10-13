
-- RUN THIS COMMAND BEFORE GOING FURTHER!
USE BRIGHT_HOUSE
GO;

/**
 *
 * NOTICE!!
 * --------
 * 
 * IN THIS SECTION, SQL THAT MODIFIES (INSERT) A NEW DATA WILL BE ACCUMULATED HERE.
 * Mostly, even though, in our project, our team focused on creating procedures that can indirectly update views
 * by modifying base relations themselves, we also allow some Views to be able to a channel to update the data.
 *
 * Therefore, there are 2 sections in this file.
 * 
 * 1. Updating data using Views
 * 2. Inserting data using Stored Procedures
 *
 */


/**
 * -- !! UPDATING DATA USING VIEWS !!
 * There are only some views that can be updated.
 * Other missing Views cannot be updated due to the fact that they are not
 * supposed to be updated since it contains aggregated columns that comes from complex join clauses.
 */

-- V2: Update payroll transaction amount based on the given transaction number
UPDATE EmployeePayrollView
SET financialTransactionAmount = 500
WHERE financialTransactionNumber = 1;

-- V3: Update the Profession and Email of the customer whose ID is 1
UPDATE CustomerView
SET profession = 'Business Sales',
    email      = 'aurion.ald@outlook.com'
WHERE customerNum = 1

-- V4: Update the returning time window for the supply number 9
UPDATE SummarySupplyView
SET supplyReturningMinuteTimeWindow = 45
WHERE supplyNumber = 9

-- V6: Update the room size of the room number 101 of branch #1
UPDATE RoomRentalStatusView
SET roomSize = 'SUP'
WHERE roomNumber = 1101

-- V13: Update the maintenance status by its number
UPDATE MaintenancePrecedingInspectionView
SET maintenanceStatus = 'Failed'
WHERE maintenanceNumber = 2

-- V16: Update the expected rental starting time of the reservation number 1
UPDATE CustomerReservationView
SET expectedCheckInDate = '2017-07-10'
WHERE reservationNumber = 1

-- V18: Update the details of the feedback with number 10
UPDATE CustomerFeedbackView
SET feedbackDescription = 'I think you guys did a good job in hospitalizing us!',
    satisfactionValue   = 10,
    rawStatus           = 'R'
WHERE feedbackNumber = 10


/**
 * -- !! INSERTING DATA USING STORED PROCEDURES !!
 */

/**
 * -- P1: Insert the details of a new branch
 */
-- Add a new branch named Ouioui located in Bangkok, Klong Toei
EXEC spInsertNewBranch @branchName = 'Ouioui', @branchBuildingNumber = '846', @branchStreetName = 'Sukhumwit',
     @branchSubDistrict = 'Phra Khanong', @branchDistrict = 'Klong Toei', @branchProvince = 'Bangkok',
     @branchPostalCode = '10260', @branchEmail = NULL,@branchTelephone = '022453587';
GO;

/**
 * -- P2: Insert the details of a new Member of an Employee
 */
-- Add a new employee named 'Apisara Ngarmsri' to the 10th branch of Bright House
EXEC spInsertEmployee @employeeFirstName = 'Apisara', @employeeMiddleName = NULL, @employeeLastName = 'Ngarmsri',
     @employeeNickname = 'Anne', @employeeTelephoneNumber='0874541672', @role='Manager', @employeeDOB='1978-2-5',
     @employeeGender='F', @employeeBuildingNumber='784', @employeeStreetName='Luang Phaeng',
     @employeeSubDistrict='Tub Yao', @employeeDistrict='Lat Krabang', @employeeProvince='Bangkok',
     @employeePostalCode='10520', @dailyWage=700, @employeeCitizenId='1107854687659', @employeeNationality='Tha',
     @employeeEmail='anne.13@gmail.com', @employeeBranchNumber=10
GO;

-- Add a new employee named 'Tanawan Ngramsri' to the 10th branch of Bright House
EXEC spInsertEmployee 'Tanawan', NULL, 'Ngarmsri',
     'Wan', '0625901002','Accountant','1978-2-5',
     'F', '784', 'Luang Phaeng',
     'Tub Yao', 'Lat Krabang', 'Bangkok',
     '10520', 700, '1107854687660', 'Tha',
     'wan.14@gmail.com', 10
GO;

/**
 * -- P2.1: Insert the employee working shift detail
 */
EXEC spInsertWorkingShift @workingDay = 'MO', @workingShiftStartingHour = 8, @workingShiftStartingMinute = 30,
     @workingShiftLengthHour = 8, @employeeNum =51
GO;

/**
 * -- P3: Insert the details of a new Customer
 */
EXEC spInsertcustomer @customerFirstName = 'Sophie', @customerMiddleName = NULL, @customerLastName = 'Ouioui',
     @customerNickname = 'Sophie', @customerTelephoneNumber='0625723493', @customerDOB='1996-2-12', @customerGender='F',
     @customerCountry='Austria', @customerCity='Vienna', @customerProfession='Pianist',
     @customerCitizenId='1107854687657', @customerNationality='Austria', @customerEmail='2ouioui@gmail.com'
GO;


/**
 * -- P3.1: Insert the details of customers Passport
 */
EXEC spInsertCustomerPassport @passportNumber = '124575689', @expirationDate='2020-10-12', @customerNum = 51
GO;


/**
 * -- P3.2: Insert the details of customers Visa
 */
EXEC spInsertCustomerVisa @visaNumber = '1112054352745', @visaClass = 'D', @immigrationNumber = 9675475,
     @arrivalDate = '2019-2-11', @departureDate = '2019-5-11', @passportNumber = 'C00817779';
GO;


/**
 * -- P4: Insert the details of a new Room in a Branch
 */
EXEC spInsertNewRoom 1, 601, 'SUP'
GO;


/**
 * -- P6: Insert the details of a new Room Utility
 */
EXEC spInsertUtilityCost @recordedTime = '2019-06-15 8:20:50.090', @electricityMeterUnit = 65, @waterMeterUnit = 59,
     @roomUtilEmployeeNum = 2, @roomUtilBranchNumber = 1, @roomUtilRoomNumber = 202,
     @utilityTimeCreated = '2019-06-15 8:40:50.090', @utilityRentalNumber = 18,
     @utilityStartingTime = '2019-06-09 01:17:40.650', @electricityUnitRate = 7, @waterunitRate = 1, @discountAmount = 0
GO;


/**
 * -- P7: Enter the details of a new Reservation
 */
EXEC spInsertReservation @reservationCreatedTime = '2020-4-25 8:20:50.090', @bookingFirstName = 'Brett',
     @bookingMiddleName = NULL, @bookingLastName = 'Eddy', @bookingContact = '00987457527', @bookingGender = 'M',
     @expectedCheckInDate = '2020-5-25', @expectedCheckOutDate = '2020-7-25', @rentalType = 'M',
     @proposedRentalPrice = 6000, @proposedDepositAmount = 3000, @branchNumber = 1, @roomNumber = 102,
     @customerNumber = 51, @managerNumber = 2
GO;


/**
 * -- P8: Enter the details of a new Rental
 */
-- Customer #51 rents 2 months
EXEC spInsertRental @reservationNumber = 1901, @rentalType = 'M', @rentalDeposit = 3000,
     @rentalStartingTime = '2020-5-25 16:20:50.090', @rentalEndingTime = '2020-7-25 11:20:50.090', @branchNumber = 1,
     @roomNumber = 102, @customer1Number = 51, @customer2Number = NULL;
GO;


/**
 * -- P9: Enter Subsequent Monthly Rental Period
 */
EXEC spInsertSubsequentMonthlyRentalPeriod @rentalNumber = 1901, @rentalPeriodStartingTime = '2020-6-1 16:20:50.090', @rentalFee = 6000
GO;


/**
 * -- P10: Enter the data of a Requested Room Service
 */
EXEC spInsertCustomerRequestedRoomService 'R', 'Cleaning Room for a customer', '2019-11-15 11:38:58.380', 1, 10,
     'Room Cleaning Service', 200, 'PA', 0, 1;
GO;


/**
 * -- P11: Enter the data of an Action done within a session of Requested Room Service
 */
EXEC spInsertActionDoneInRequestedRoomService 1, 836, 14343, NULL, 'Floor sweeping';
GO;


/**
 * -- P12: Add a Supply Withdrawal entry associated with Customer Service.
 */
EXEC spInsertWithdrawalEntryRelatedToCustomerService
     18, 'Cleaning Supply', 1, 1, 41, NULL, NULL, NULL, NULL;
GO;


/**
 * -- P13: Enter the data of an Action done with a Routine Room Service
 */
EXEC spInsertRoutineRoomServiceAction 1, 6;
GO;


/**
 * -- P14: Add a new Supply from a purchasing to the inventory
 */
EXEC spInsertNewSupplyFromPurchasingToInventory 2, 1244, 'Receiving supply from a vendor', 43;
GO;



/**
 * -- P23: Insert the details of a Property Inspection
 */
EXEC spInsertPropertyInspection 1, 1, 'Everything is good!';


/**
 * -- P24: Insert the details of a Property Damage
 */
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


/**
 * -- P25: Insert the details of a Maintenance
 */
EXEC spInsertMaintenanceTask 'Fix these objects', 'Building', 1, 1, 2, 3, NULL, NULL;
GO;


/**
 * -- P27: Enter the data of a Routine Room Service
 */
EXEC spInsertRoutineRoomService 'R', 'Cleaning Room for a customer', '2019-11-15 11:38:58.380', 1, 10
GO;