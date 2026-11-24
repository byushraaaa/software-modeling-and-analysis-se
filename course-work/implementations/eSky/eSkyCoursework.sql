/*
  eSky.com coursework database - beginner-friendly version
  Focus: one booking has one flight, optional one hotel, one or more passengers.
  Many-to-many: BOOKING <-> PASSENGER through BOOKING_PASSENGER.
*/
IF DB_ID(N'eSkyCoursework') IS NULL
    CREATE DATABASE eSkyCoursework;
GO
USE eSkyCoursework;
GO

-- 1. Currency
IF OBJECT_ID(N'dbo.CURRENCY', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CURRENCY (
        CurrencyId INT IDENTITY(1,1) PRIMARY KEY,
        CurrencyCode CHAR(3) NOT NULL UNIQUE,
        CurrencyName NVARCHAR(40) NOT NULL
    );
END;
GO

-- 2. Customer
IF OBJECT_ID(N'dbo.CUSTOMER', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CUSTOMER (
        CustomerId INT IDENTITY(1,1) PRIMARY KEY,
        FirstName NVARCHAR(50) NOT NULL,
        LastName NVARCHAR(50) NOT NULL,
        Email NVARCHAR(120) NOT NULL UNIQUE,
        Phone NVARCHAR(30) NULL,
        CreatedAt DATE NOT NULL DEFAULT (CONVERT(date, GETDATE()))
    );
END;
GO

-- 3. Passenger
IF OBJECT_ID(N'dbo.PASSENGER', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PASSENGER (
        PassengerId INT IDENTITY(1,1) PRIMARY KEY,
        FirstName NVARCHAR(50) NOT NULL,
        LastName NVARCHAR(50) NOT NULL,
        DateOfBirth DATE NOT NULL,
        Nationality NVARCHAR(50) NOT NULL,
        PassportNumber NVARCHAR(30) NULL
    );
END;
GO

-- 4. Flight (airline and route are kept here to keep the model simple)
IF OBJECT_ID(N'dbo.FLIGHT', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FLIGHT (
        FlightId INT IDENTITY(1,1) PRIMARY KEY,
        AirlineName NVARCHAR(80) NOT NULL,
        FlightNumber NVARCHAR(20) NOT NULL,
        Origin NVARCHAR(80) NOT NULL,
        Destination NVARCHAR(80) NOT NULL,
        DepartureTime DATETIME2 NOT NULL,
        ArrivalTime DATETIME2 NOT NULL,
        BasePrice DECIMAL(10,2) NOT NULL CHECK (BasePrice >= 0),
        CONSTRAINT CK_FLIGHT_Times CHECK (ArrivalTime > DepartureTime)
    );
END;
GO

-- 5. Hotel
IF OBJECT_ID(N'dbo.HOTEL', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HOTEL (
        HotelId INT IDENTITY(1,1) PRIMARY KEY,
        HotelName NVARCHAR(100) NOT NULL,
        City NVARCHAR(80) NOT NULL,
        Country NVARCHAR(80) NOT NULL,
        StarRating TINYINT NOT NULL CHECK (StarRating BETWEEN 1 AND 5),
        PricePerNight DECIMAL(10,2) NOT NULL CHECK (PricePerNight >= 0)
    );
END;
GO

-- 6. Booking
IF OBJECT_ID(N'dbo.BOOKING', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BOOKING (
        BookingId INT IDENTITY(1,1) PRIMARY KEY,
        CustomerId INT NOT NULL,
        FlightId INT NOT NULL,
        HotelId INT NULL,
        CurrencyId INT NOT NULL,
        BookingReference NVARCHAR(20) NOT NULL UNIQUE,
        BookingDate DATE NOT NULL DEFAULT (CONVERT(date, GETDATE())),
        DepartureDate DATE NOT NULL,
        ReturnDate DATE NOT NULL,
        BookingStatus NVARCHAR(20) NOT NULL DEFAULT N'PendingPayment',
        TotalAmount DECIMAL(10,2) NOT NULL DEFAULT 0,
        CONSTRAINT FK_BOOKING_Customer FOREIGN KEY (CustomerId) REFERENCES dbo.CUSTOMER(CustomerId),
        CONSTRAINT FK_BOOKING_Flight FOREIGN KEY (FlightId) REFERENCES dbo.FLIGHT(FlightId),
        CONSTRAINT FK_BOOKING_Hotel FOREIGN KEY (HotelId) REFERENCES dbo.HOTEL(HotelId),
        CONSTRAINT FK_BOOKING_Currency FOREIGN KEY (CurrencyId) REFERENCES dbo.CURRENCY(CurrencyId),
        CONSTRAINT CK_BOOKING_Dates CHECK (ReturnDate > DepartureDate),
        CONSTRAINT CK_BOOKING_Status CHECK (BookingStatus IN (N'PendingPayment', N'PartiallyPaid', N'Confirmed', N'Cancelled'))
    );
END;
GO

-- 7. Bridge table: lets one booking have several passengers, and each passenger
--    can be included in different bookings over time.
IF OBJECT_ID(N'dbo.BOOKING_PASSENGER', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BOOKING_PASSENGER (
        BookingId INT NOT NULL,
        PassengerId INT NOT NULL,
        PassengerRole NVARCHAR(20) NOT NULL DEFAULT N'Traveller',
        CONSTRAINT PK_BOOKING_PASSENGER PRIMARY KEY (BookingId, PassengerId),
        CONSTRAINT FK_BP_Booking FOREIGN KEY (BookingId) REFERENCES dbo.BOOKING(BookingId),
        CONSTRAINT FK_BP_Passenger FOREIGN KEY (PassengerId) REFERENCES dbo.PASSENGER(PassengerId)
    );
END;
GO

-- 8. Payment
IF OBJECT_ID(N'dbo.PAYMENT', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PAYMENT (
        PaymentId INT IDENTITY(1,1) PRIMARY KEY,
        BookingId INT NOT NULL,
        PaymentDate DATETIME2 NOT NULL DEFAULT (SYSDATETIME()),
        Amount DECIMAL(10,2) NOT NULL CHECK (Amount >= 0),
        PaymentMethod NVARCHAR(30) NOT NULL,
        PaymentStatus NVARCHAR(20) NOT NULL,
        CONSTRAINT FK_PAYMENT_Booking FOREIGN KEY (BookingId) REFERENCES dbo.BOOKING(BookingId),
        CONSTRAINT CK_PAYMENT_Status CHECK (PaymentStatus IN (N'Succeeded', N'Failed', N'Refunded'))
    );
END;
GO

-- Function: calculate a booking price from its flight and hotel.
CREATE OR ALTER FUNCTION dbo.fn_BookingTotal (@BookingId INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Total DECIMAL(10,2);

    SELECT @Total = f.BasePrice +
        CASE WHEN b.HotelId IS NULL THEN 0
             ELSE h.PricePerNight * DATEDIFF(DAY, b.DepartureDate, b.ReturnDate)
        END
    FROM dbo.BOOKING AS b
    JOIN dbo.FLIGHT AS f ON f.FlightId = b.FlightId
    LEFT JOIN dbo.HOTEL AS h ON h.HotelId = b.HotelId
    WHERE b.BookingId = @BookingId;

    RETURN COALESCE(@Total, 0);
END;
GO

-- Stored procedure: create one booking for one customer and one main passenger.
CREATE OR ALTER PROCEDURE dbo.usp_CreateBooking
    @CustomerId INT,
    @PassengerId INT,
    @FlightId INT,
    @HotelId INT,
    @CurrencyId INT,
    @BookingReference NVARCHAR(20),
    @DepartureDate DATE,
    @ReturnDate DATE,
    @BookingId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.BOOKING
        (CustomerId, FlightId, HotelId, CurrencyId, BookingReference,
         DepartureDate, ReturnDate, BookingStatus, TotalAmount)
    VALUES
        (@CustomerId, @FlightId, @HotelId, @CurrencyId, @BookingReference,
         @DepartureDate, @ReturnDate, N'PendingPayment', 0);

    SET @BookingId = CONVERT(INT, SCOPE_IDENTITY());

    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId)
    VALUES (@BookingId, @PassengerId);

    UPDATE dbo.BOOKING
    SET TotalAmount = dbo.fn_BookingTotal(@BookingId)
    WHERE BookingId = @BookingId;
END;
GO

-- Trigger: update booking status when a payment is added or changed.
CREATE OR ALTER TRIGGER dbo.trg_Payment_UpdateBookingStatus
ON dbo.PAYMENT
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH ChangedBookings AS (
        SELECT BookingId FROM inserted
        UNION
        SELECT BookingId FROM deleted
    ), PaidTotals AS (
        SELECT p.BookingId,
               SUM(CASE WHEN p.PaymentStatus = N'Succeeded' THEN p.Amount
                        WHEN p.PaymentStatus = N'Refunded' THEN -p.Amount
                        ELSE 0 END) AS PaidAmount
        FROM dbo.PAYMENT AS p
        JOIN ChangedBookings AS c ON c.BookingId = p.BookingId
        GROUP BY p.BookingId
    )
    UPDATE b
    SET BookingStatus = CASE
        WHEN b.BookingStatus = N'Cancelled' THEN N'Cancelled'
        WHEN COALESCE(p.PaidAmount, 0) >= b.TotalAmount THEN N'Confirmed'
        WHEN COALESCE(p.PaidAmount, 0) > 0 THEN N'PartiallyPaid'
        ELSE N'PendingPayment'
    END
    FROM dbo.BOOKING AS b
    JOIN ChangedBookings AS c ON c.BookingId = b.BookingId
    LEFT JOIN PaidTotals AS p ON p.BookingId = b.BookingId;
END;
GO

-- Sample data: run-safe inserts, with three different booking/payment outcomes.
IF NOT EXISTS (SELECT 1 FROM dbo.CURRENCY WHERE CurrencyCode = 'EUR')
    INSERT INTO dbo.CURRENCY (CurrencyCode, CurrencyName) VALUES ('EUR', N'Euro');

IF NOT EXISTS (SELECT 1 FROM dbo.CUSTOMER WHERE Email = N'maria@example.com')
    INSERT INTO dbo.CUSTOMER (FirstName, LastName, Email, Phone) VALUES
    (N'Maria', N'Ivanova', N'maria@example.com', N'+359 888 100 101');
IF NOT EXISTS (SELECT 1 FROM dbo.CUSTOMER WHERE Email = N'georgi@example.com')
    INSERT INTO dbo.CUSTOMER (FirstName, LastName, Email, Phone) VALUES
    (N'Georgi', N'Petrov', N'georgi@example.com', N'+359 888 100 102');
IF NOT EXISTS (SELECT 1 FROM dbo.CUSTOMER WHERE Email = N'elena@example.com')
    INSERT INTO dbo.CUSTOMER (FirstName, LastName, Email, Phone) VALUES
    (N'Elena', N'Dimitrova', N'elena@example.com', N'+359 888 100 103');

IF NOT EXISTS (SELECT 1 FROM dbo.PASSENGER WHERE PassportNumber = N'BG100001')
    INSERT INTO dbo.PASSENGER (FirstName, LastName, DateOfBirth, Nationality, PassportNumber)
    VALUES (N'Maria', N'Ivanova', '1998-04-12', N'Bulgarian', N'BG100001');
IF NOT EXISTS (SELECT 1 FROM dbo.PASSENGER WHERE PassportNumber = N'BG100002')
    INSERT INTO dbo.PASSENGER (FirstName, LastName, DateOfBirth, Nationality, PassportNumber)
    VALUES (N'Georgi', N'Petrov', '1995-09-03', N'Bulgarian', N'BG100002');
IF NOT EXISTS (SELECT 1 FROM dbo.PASSENGER WHERE PassportNumber = N'BG100003')
    INSERT INTO dbo.PASSENGER (FirstName, LastName, DateOfBirth, Nationality, PassportNumber)
    VALUES (N'Elena', N'Dimitrova', '2001-01-25', N'Bulgarian', N'BG100003');

IF NOT EXISTS (SELECT 1 FROM dbo.FLIGHT WHERE FlightNumber = N'ES101')
    INSERT INTO dbo.FLIGHT (AirlineName, FlightNumber, Origin, Destination, DepartureTime, ArrivalTime, BasePrice)
    VALUES (N'eSky Demo Air', N'ES101', N'Sofia', N'Rome', '2027-05-10T08:00:00', '2027-05-10T09:30:00', 220.00);
IF NOT EXISTS (SELECT 1 FROM dbo.FLIGHT WHERE FlightNumber = N'ES202')
    INSERT INTO dbo.FLIGHT (AirlineName, FlightNumber, Origin, Destination, DepartureTime, ArrivalTime, BasePrice)
    VALUES (N'eSky Demo Air', N'ES202', N'Sofia', N'Paris', '2027-06-15T10:00:00', '2027-06-15T12:30:00', 280.00);
IF NOT EXISTS (SELECT 1 FROM dbo.FLIGHT WHERE FlightNumber = N'ES303')
    INSERT INTO dbo.FLIGHT (AirlineName, FlightNumber, Origin, Destination, DepartureTime, ArrivalTime, BasePrice)
    VALUES (N'eSky Demo Air', N'ES303', N'Sofia', N'London', '2027-07-01T07:30:00', '2027-07-01T09:45:00', 310.00);

IF NOT EXISTS (SELECT 1 FROM dbo.HOTEL WHERE HotelName = N'Roma Centro')
    INSERT INTO dbo.HOTEL (HotelName, City, Country, StarRating, PricePerNight)
    VALUES (N'Roma Centro', N'Rome', N'Italy', 4, 120.00);
IF NOT EXISTS (SELECT 1 FROM dbo.HOTEL WHERE HotelName = N'Paris Lumiere')
    INSERT INTO dbo.HOTEL (HotelName, City, Country, StarRating, PricePerNight)
    VALUES (N'Paris Lumiere', N'Paris', N'France', 4, 150.00);
IF NOT EXISTS (SELECT 1 FROM dbo.HOTEL WHERE HotelName = N'London Bridge Hotel')
    INSERT INTO dbo.HOTEL (HotelName, City, Country, StarRating, PricePerNight)
    VALUES (N'London Bridge Hotel', N'London', N'United Kingdom', 3, 170.00);

DECLARE @EUR INT = (SELECT CurrencyId FROM dbo.CURRENCY WHERE CurrencyCode = 'EUR');
DECLARE @Customer1 INT = (SELECT CustomerId FROM dbo.CUSTOMER WHERE Email = N'maria@example.com');
DECLARE @Customer2 INT = (SELECT CustomerId FROM dbo.CUSTOMER WHERE Email = N'georgi@example.com');
DECLARE @Customer3 INT = (SELECT CustomerId FROM dbo.CUSTOMER WHERE Email = N'elena@example.com');
DECLARE @Passenger1 INT = (SELECT PassengerId FROM dbo.PASSENGER WHERE PassportNumber = N'BG100001');
DECLARE @Passenger2 INT = (SELECT PassengerId FROM dbo.PASSENGER WHERE PassportNumber = N'BG100002');
DECLARE @Passenger3 INT = (SELECT PassengerId FROM dbo.PASSENGER WHERE PassportNumber = N'BG100003');
DECLARE @Flight1 INT = (SELECT FlightId FROM dbo.FLIGHT WHERE FlightNumber = N'ES101');
DECLARE @Flight2 INT = (SELECT FlightId FROM dbo.FLIGHT WHERE FlightNumber = N'ES202');
DECLARE @Flight3 INT = (SELECT FlightId FROM dbo.FLIGHT WHERE FlightNumber = N'ES303');
DECLARE @Hotel1 INT = (SELECT HotelId FROM dbo.HOTEL WHERE HotelName = N'Roma Centro');
DECLARE @Hotel2 INT = (SELECT HotelId FROM dbo.HOTEL WHERE HotelName = N'Paris Lumiere');
DECLARE @Hotel3 INT = (SELECT HotelId FROM dbo.HOTEL WHERE HotelName = N'London Bridge Hotel');

IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING WHERE BookingReference = N'ESKY-2027-001')
BEGIN
    INSERT INTO dbo.BOOKING (CustomerId, FlightId, HotelId, CurrencyId, BookingReference, DepartureDate, ReturnDate, TotalAmount)
    VALUES (@Customer1, @Flight1, @Hotel1, @EUR, N'ESKY-2027-001', '2027-05-10', '2027-05-13', 580.00);
END;
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING WHERE BookingReference = N'ESKY-2027-002')
BEGIN
    INSERT INTO dbo.BOOKING (CustomerId, FlightId, HotelId, CurrencyId, BookingReference, DepartureDate, ReturnDate, TotalAmount)
    VALUES (@Customer2, @Flight2, @Hotel2, @EUR, N'ESKY-2027-002', '2027-06-15', '2027-06-18', 730.00);
END;
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING WHERE BookingReference = N'ESKY-2027-003')
BEGIN
    INSERT INTO dbo.BOOKING (CustomerId, FlightId, HotelId, CurrencyId, BookingReference, DepartureDate, ReturnDate, TotalAmount)
    VALUES (@Customer3, @Flight3, @Hotel3, @EUR, N'ESKY-2027-003', '2027-07-01', '2027-07-04', 820.00);
END;

DECLARE @Booking1 INT = (SELECT BookingId FROM dbo.BOOKING WHERE BookingReference = N'ESKY-2027-001');
DECLARE @Booking2 INT = (SELECT BookingId FROM dbo.BOOKING WHERE BookingReference = N'ESKY-2027-002');
DECLARE @Booking3 INT = (SELECT BookingId FROM dbo.BOOKING WHERE BookingReference = N'ESKY-2027-003');

IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking1 AND PassengerId=@Passenger1)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking1, @Passenger1);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking2 AND PassengerId=@Passenger2)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking2, @Passenger2);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking3 AND PassengerId=@Passenger3)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking3, @Passenger3);

IF NOT EXISTS (SELECT 1 FROM dbo.PAYMENT WHERE BookingId=@Booking1 AND PaymentStatus=N'Succeeded')
    INSERT INTO dbo.PAYMENT (BookingId, Amount, PaymentMethod, PaymentStatus)
    VALUES (@Booking1, 580.00, N'Card', N'Succeeded');
IF NOT EXISTS (SELECT 1 FROM dbo.PAYMENT WHERE BookingId=@Booking2 AND PaymentStatus=N'Succeeded')
    INSERT INTO dbo.PAYMENT (BookingId, Amount, PaymentMethod, PaymentStatus)
    VALUES (@Booking2, 300.00, N'Card', N'Succeeded');
IF NOT EXISTS (SELECT 1 FROM dbo.PAYMENT WHERE BookingId=@Booking3 AND PaymentStatus=N'Failed')
    INSERT INTO dbo.PAYMENT (BookingId, Amount, PaymentMethod, PaymentStatus)
    VALUES (@Booking3, 820.00, N'Card', N'Failed');
GO

-- Quick presentation queries
SELECT BookingReference, BookingStatus, TotalAmount FROM dbo.BOOKING ORDER BY BookingId;
SELECT dbo.fn_BookingTotal(BookingId) AS CalculatedTotal, BookingReference FROM dbo.BOOKING ORDER BY BookingId;


