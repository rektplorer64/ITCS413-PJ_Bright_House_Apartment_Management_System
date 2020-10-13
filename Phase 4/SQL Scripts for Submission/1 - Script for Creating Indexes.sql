USE BRIGHT_HOUSE
GO;


/**
 *
 * NOTICE!!
 * --------
 *
 * IN THIS SECTION, SQL COMMANDS FOR THE CREATION OF ADDITIONAL INDEXES.
 * INDEXES ON PRIMARY KEY ARE NOT BEING CONSIDERED SINCE
 */

/**
 * -- I1: Branch Indexes
 */

-- Non-clustered index on branchName
CREATE UNIQUE NONCLUSTERED INDEX idxBranchNamePK ON Branch (branchName)
GO;

-- Non-clustered index on branchProvince
CREATE NONCLUSTERED INDEX idxBranchProvince ON Branch (branchProvince)
GO;

-- Non-clustered index on branchNumber, branchName, branchEmail
CREATE UNIQUE NONCLUSTERED INDEX idxBranchEmail ON Branch (branchNumber, branchName, branchEmail)
GO;


/**
 * -- I2: Customer Indexes
 */
-- Non-clustered index on GROUPING FIELDS -> customerNum, customerFirstName, customerMiddleName, customerLastName
CREATE UNIQUE NONCLUSTERED INDEX idxCustomerMainDetails ON Customer(customerNum, customerFirstName, customerMiddleName, customerLastName)
GO;

-- Non-clustered index on customer first name, middle name and last name
CREATE NONCLUSTERED INDEX idxCustomerName ON Customer(customerFirstName ASC, customerMiddleName ASC, customerLastName DESC)
GO;

-- Non-clustered index on customer nationality
CREATE NONCLUSTERED INDEX idxCustomerNationality ON Customer(customerNationality)
GO;

-- Non-clustered index on customerDOB
CREATE NONCLUSTERED INDEX idxCustomerDOB ON Customer(customerDOB)
GO;


/**
 * -- I3: CustomerBilling Indexes
 */
-- Non-clustered index on GROUPING FIELDS -> billingNumber, billingDescription, billingCreatedTime
CREATE UNIQUE NONCLUSTERED INDEX idxCustomerBillingMainDetails ON CustomerBilling(billingNumber, billingDescription, billingCreatedTime)
GO;

-- Non-clustered index on FK customer number
CREATE NONCLUSTERED INDEX idxFkCustomerBilling_CustomerNum ON CustomerBilling(billingCustomerNum)
GO;

-- Non-clustered index on FK financial transaction number
CREATE NONCLUSTERED INDEX idxFkCustomerBilling_FinancialTransactionNum ON CustomerBilling(billingFinancialTransactionNumber)
GO;

-- Non-clustered index on FK rental number
CREATE NONCLUSTERED INDEX idxFkCustomerBilling_RentalNum ON CustomerBilling(billingRentalNumber)
GO;


/**
 * -- I4: CustomerBillingLine Indexes
 */
-- Non-clustered index on FK customer billing number and billing time
CREATE UNIQUE NONCLUSTERED INDEX idxFkCustomerBillingLineBilling ON CustomerBillingLine(customerBillingNumber, customerBillingTime)
GO;


/**
 * -- I5: CustomerPassport Indexes
 */
-- Non-clustered index on FK customer passport
CREATE NONCLUSTERED INDEX idxFkCustomerPassport_CustomerNum ON CustomerPassport(passportCustomerNum)
GO;

-- Non-clustered index on FK customer passport expiration date
CREATE NONCLUSTERED INDEX idxCustomerPassportExpirationDate ON CustomerPassport(expirationDate)
GO;

/**
 * -- I6: CustomerTelephone Indexes
 */
CREATE NONCLUSTERED INDEX idxFkCustomerTelephone_CustomerNum ON CustomerTelephone(customerTelephoneNumber)
GO;


/**
 * -- I7: CustomerVisa Indexes
 */
CREATE NONCLUSTERED INDEX idxFkCustomer_VisaPassportNum ON CustomerVisa(visaPassportNumber)
GO;

CREATE NONCLUSTERED INDEX idxCustomerVisaArrivalDate ON CustomerVisa(arrivalDate)
GO;


/**
 * -- I8: Employee Indexes
 */
CREATE NONCLUSTERED INDEX idxEmployeeBranchNumber ON Employee(employeeBranchNumber)
GO;

CREATE NONCLUSTERED INDEX idxEmployeeName ON Employee(employeeFirstName ASC, employeeMiddleName ASC, employeeLastName DESC)
GO;


/**
 * -- I9: FinancialTransaction Indexes
 */
CREATE NONCLUSTERED INDEX idxFinancialTransactionAmount ON FinancialTransaction(financialTransactionAmount)
GO;


/**
 * -- I10: InventoryEntry Indexes
 */
CREATE NONCLUSTERED INDEX idxFkInventoryEntry_ReturningSupplyNum ON InventoryEntry(entryReturningSupplyNumber)
GO;

CREATE NONCLUSTERED INDEX idxFkInventoryEntry_SupplyNum ON InventoryEntry(entrySupplyNumber)
GO;

CREATE NONCLUSTERED INDEX idxFkInventoryEntry_BranchNum ON InventoryEntry(entryBranchNumber)
GO;

CREATE NONCLUSTERED INDEX idxInventoryEntryType ON InventoryEntry(inventoryEntryType)
GO;


/**
 * -- I11: PropertyDamage Indexes
 */
CREATE NONCLUSTERED INDEX idxFkPropertyDamage_maintenanceNum ON PropertyDamage(propertyDamageMaintenanceNumber)
GO;

CREATE NONCLUSTERED INDEX idxFkPropertyDamage_propertyInspectionNum ON PropertyDamage(propertyDamageInspectionNumber)
GO;


/**
 * -- I12: PropertyInspection Indexes
 */
CREATE NONCLUSTERED INDEX idxFkPropertyInspection_rentalNum ON PropertyInspection(propertyInspectionRentalNumber)
GO;


/**
 * -- I13: Purchasing Indexes
 */
CREATE NONCLUSTERED INDEX idxPurchasingType ON Purchasing(purchasingType)
GO;


/**
 * -- I14: Rental Indexes
 */
CREATE NONCLUSTERED INDEX idxRentalTimePeriod ON Rental(rentalStartingTime DESC, rentalEndingTime DESC)
GO;

CREATE NONCLUSTERED INDEX idxRentalEndingTime ON Rental(rentalEndingTime)
GO;

CREATE NONCLUSTERED INDEX idxFkRental_branchNum ON Rental(rentalBranchNumber)
GO;

CREATE NONCLUSTERED INDEX idxFkRental_bookingCustomerNum ON Rental(rentalBookingCustomerNum)
GO;

CREATE NONCLUSTERED INDEX idxFkRental_roomNum ON Rental(rentalRoomNumber)
GO;


/**
 * -- I15: RentalCustomer Indexes
 */
CREATE NONCLUSTERED INDEX idxFkRentalCustomer_rentalNum ON RentalCustomer(rentalCustomerRentalNumber)
GO;

CREATE NONCLUSTERED INDEX idxFkRentalCustomer_customerNum ON RentalCustomer(rentalCustomerNum)
GO;


/**
 * -- I16: RentalPeriod Indexes
 */
CREATE NONCLUSTERED INDEX idxRentalPeriodStartingTime ON RentalPeriod(rentalPeriodStartingTime)
GO;

CREATE NONCLUSTERED INDEX idxRentalPeriodEndingTime ON RentalPeriod(rentalPeriodEndingTime)
GO;


/**
 * -- I17: RequestedRoomService Indexes
 */
CREATE NONCLUSTERED INDEX idxFkRequestedRoomService_serviceNum ON RequestedRoomService(requestedServiceNumber)
GO;

CREATE NONCLUSTERED INDEX idxFkRequestedRoomService_billingFullNum ON RequestedRoomService(requestedBillingNumber, requestedLineNumber)
GO;


/**
 * -- I18: Reservation Indexes
 */
-- Reservation Check-in and Check-out dates are usually used to determine availability of rooms.
CREATE NONCLUSTERED INDEX idxFkReservation_expectedCheckInDate ON Reservation(expectedCheckInDate)
GO;

CREATE NONCLUSTERED INDEX idxFkReservation_expectedCheckOutDate ON Reservation(expectedCheckOutDate)
GO;


/**
 * -- I19: ReservedRoom Indexes
 */
CREATE NONCLUSTERED INDEX idxFkReservedRoom_room ON ReservedRoom(reservedRoomReservationNumber, reservedRoomBranchNumber)
GO;


/**
 * -- I20: RoomUtilityRecord Indexes
 */
-- Facilitate Searches related to rooms
CREATE NONCLUSTERED INDEX idxFkRoomUtilityRecord_branchNum ON RoomUtilityRecord(roomUtilBranchNumber)
GO;

CREATE NONCLUSTERED INDEX idxFkRoomUtilityRecord_roomNum ON RoomUtilityRecord(roomUtilRoomNumber)
GO;

-- Facilitates Searches related to the recording time
CREATE NONCLUSTERED INDEX idxRoomUtilityRecordRecordedTime ON RoomUtilityRecord(recordedTime)
GO;


/**
 * -- I22: UtilityCost Indexes
 */
-- Facilitates JOINING with CustomerBillingLine relation by indexing its foreign key.
CREATE NONCLUSTERED INDEX idxFkUtilityCost_billing ON UtilityCost(utilityBillingNumber, utilityLineNumber)
GO;