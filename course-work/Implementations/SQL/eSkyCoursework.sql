/*
  eSky.com coursework database - beginner-friendly version
  Focus: one booking has one flight, an optional hotel, and one or more passengers.
  Many-to-many: BOOKING <-> PASSENGER through BOOKING_PASSENGER.
  Second many-to-many: HOTEL <-> AMENITY through HOTEL_AMENITY.
  Sample dataset: 10 customers, 10 passengers, 10 flights, 8 hotels, 6 amenities, 12 bookings.
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
        PricePerNight DECIMAL(10,2) NOT NULL CHECK (PricePerNight >= 0),
        AmenityCount INT NOT NULL DEFAULT 0 CHECK (AmenityCount >= 0)
    );
END;
GO

-- Add the count column when upgrading an existing coursework database.
IF COL_LENGTH(N'dbo.HOTEL', N'AmenityCount') IS NULL
    ALTER TABLE dbo.HOTEL ADD AmenityCount INT NOT NULL
        CONSTRAINT DF_HOTEL_AmenityCount DEFAULT 0 CHECK (AmenityCount >= 0);
GO

-- 6-7. Amenity catalogue and bridge (second many-to-many relation).
IF OBJECT_ID(N'dbo.AMENITY', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AMENITY (
        AmenityId INT IDENTITY(1,1) PRIMARY KEY,
        AmenityName NVARCHAR(50) NOT NULL UNIQUE,
        Category NVARCHAR(30) NOT NULL
    );
END;
GO

IF OBJECT_ID(N'dbo.HOTEL_AMENITY', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HOTEL_AMENITY (
        HotelId INT NOT NULL,
        AmenityId INT NOT NULL,
        CONSTRAINT PK_HOTEL_AMENITY PRIMARY KEY (HotelId, AmenityId),
        CONSTRAINT FK_HA_Hotel FOREIGN KEY (HotelId) REFERENCES dbo.HOTEL(HotelId),
        CONSTRAINT FK_HA_Amenity FOREIGN KEY (AmenityId) REFERENCES dbo.AMENITY(AmenityId)
    );
END;
GO

-- 8. Booking
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

-- 9. Bridge table: lets one booking have several passengers, and each passenger
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

-- 10. Payment
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

-- Function: count the amenities assigned to one hotel.
CREATE OR ALTER FUNCTION dbo.fn_HotelAmenityCount (@HotelId INT)
RETURNS INT
AS
BEGIN
    DECLARE @Count INT;
    SELECT @Count = COUNT(*) FROM dbo.HOTEL_AMENITY WHERE HotelId = @HotelId;
    RETURN COALESCE(@Count, 0);
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

-- Stored procedure: add an amenity to a hotel without creating a duplicate.
CREATE OR ALTER PROCEDURE dbo.usp_AddAmenityToHotel
    @HotelId INT,
    @AmenityId INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.HOTEL_AMENITY
        WHERE HotelId = @HotelId AND AmenityId = @AmenityId
    )
        INSERT INTO dbo.HOTEL_AMENITY (HotelId, AmenityId)
        VALUES (@HotelId, @AmenityId);
END;
GO

-- Stored procedure: add a passenger to an existing booking.
CREATE OR ALTER PROCEDURE dbo.usp_AddPassengerToBooking
    @BookingId INT,
    @PassengerId INT,
    @PassengerRole NVARCHAR(20) = N'Traveller'
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.BOOKING_PASSENGER
        WHERE BookingId = @BookingId AND PassengerId = @PassengerId
    )
        INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId, PassengerRole)
        VALUES (@BookingId, @PassengerId, @PassengerRole);
END;
GO

-- Trigger: initialize total price when a booking is created.
CREATE OR ALTER TRIGGER dbo.trg_Booking_SetInitialTotal
ON dbo.BOOKING
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE b
    SET TotalAmount = dbo.fn_BookingTotal(b.BookingId)
    FROM dbo.BOOKING AS b
    JOIN inserted AS i ON i.BookingId = b.BookingId;
END;
GO

-- Trigger: maintain the amenity count shown on each hotel.
CREATE OR ALTER TRIGGER dbo.trg_HotelAmenity_UpdateCount
ON dbo.HOTEL_AMENITY
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH ChangedHotels AS (
        SELECT HotelId FROM inserted
        UNION
        SELECT HotelId FROM deleted
    )
    UPDATE h
    SET AmenityCount = dbo.fn_HotelAmenityCount(h.HotelId)
    FROM dbo.HOTEL AS h
    JOIN ChangedHotels AS c ON c.HotelId = h.HotelId;
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

-- Sample data: run-safe inserts for twelve bookings and several payment outcomes.
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

IF NOT EXISTS (SELECT 1 FROM dbo.CUSTOMER WHERE Email=N'nina@example.com')
    INSERT INTO dbo.CUSTOMER (FirstName, LastName, Email, Phone) VALUES
    (N'Nina', N'Stoyanova', N'nina@example.com', N'+359 888 100 104');
IF NOT EXISTS (SELECT 1 FROM dbo.CUSTOMER WHERE Email=N'petar@example.com')
    INSERT INTO dbo.CUSTOMER (FirstName, LastName, Email, Phone) VALUES
    (N'Petar', N'Kolev', N'petar@example.com', N'+359 888 100 105');
IF NOT EXISTS (SELECT 1 FROM dbo.CUSTOMER WHERE Email=N'sara@example.com')
    INSERT INTO dbo.CUSTOMER (FirstName, LastName, Email, Phone) VALUES
    (N'Sara', N'Ivanova', N'sara@example.com', N'+359 888 100 106');
IF NOT EXISTS (SELECT 1 FROM dbo.CUSTOMER WHERE Email=N'viktor@example.com')
    INSERT INTO dbo.CUSTOMER (FirstName, LastName, Email, Phone) VALUES
    (N'Viktor', N'Nikolov', N'viktor@example.com', N'+359 888 100 107');
IF NOT EXISTS (SELECT 1 FROM dbo.CUSTOMER WHERE Email=N'daria@example.com')
    INSERT INTO dbo.CUSTOMER (FirstName, LastName, Email, Phone) VALUES
    (N'Daria', N'Georgieva', N'daria@example.com', N'+359 888 100 108');
IF NOT EXISTS (SELECT 1 FROM dbo.CUSTOMER WHERE Email=N'alex@example.com')
    INSERT INTO dbo.CUSTOMER (FirstName, LastName, Email, Phone) VALUES
    (N'Alex', N'Marinov', N'alex@example.com', N'+359 888 100 109');
IF NOT EXISTS (SELECT 1 FROM dbo.CUSTOMER WHERE Email=N'iva@example.com')
    INSERT INTO dbo.CUSTOMER (FirstName, LastName, Email, Phone) VALUES
    (N'Iva', N'Petrova', N'iva@example.com', N'+359 888 100 110');

IF NOT EXISTS (SELECT 1 FROM dbo.PASSENGER WHERE PassportNumber = N'BG100001')
    INSERT INTO dbo.PASSENGER (FirstName, LastName, DateOfBirth, Nationality, PassportNumber)
    VALUES (N'Maria', N'Ivanova', '1998-04-12', N'Bulgarian', N'BG100001');
IF NOT EXISTS (SELECT 1 FROM dbo.PASSENGER WHERE PassportNumber = N'BG100002')
    INSERT INTO dbo.PASSENGER (FirstName, LastName, DateOfBirth, Nationality, PassportNumber)
    VALUES (N'Georgi', N'Petrov', '1995-09-03', N'Bulgarian', N'BG100002');
IF NOT EXISTS (SELECT 1 FROM dbo.PASSENGER WHERE PassportNumber = N'BG100003')
    INSERT INTO dbo.PASSENGER (FirstName, LastName, DateOfBirth, Nationality, PassportNumber)
    VALUES (N'Elena', N'Dimitrova', '2001-01-25', N'Bulgarian', N'BG100003');

IF NOT EXISTS (SELECT 1 FROM dbo.PASSENGER WHERE PassportNumber=N'BG100004')
    INSERT INTO dbo.PASSENGER (FirstName, LastName, DateOfBirth, Nationality, PassportNumber)
    VALUES (N'Nina', N'Stoyanova', '1997-02-10', N'Bulgarian', N'BG100004');
IF NOT EXISTS (SELECT 1 FROM dbo.PASSENGER WHERE PassportNumber=N'BG100005')
    INSERT INTO dbo.PASSENGER (FirstName, LastName, DateOfBirth, Nationality, PassportNumber)
    VALUES (N'Petar', N'Kolev', '1990-07-14', N'Bulgarian', N'BG100005');
IF NOT EXISTS (SELECT 1 FROM dbo.PASSENGER WHERE PassportNumber=N'BG100006')
    INSERT INTO dbo.PASSENGER (FirstName, LastName, DateOfBirth, Nationality, PassportNumber)
    VALUES (N'Sara', N'Ivanova', '1999-11-02', N'Bulgarian', N'BG100006');
IF NOT EXISTS (SELECT 1 FROM dbo.PASSENGER WHERE PassportNumber=N'BG100007')
    INSERT INTO dbo.PASSENGER (FirstName, LastName, DateOfBirth, Nationality, PassportNumber)
    VALUES (N'Viktor', N'Nikolov', '1994-05-21', N'Bulgarian', N'BG100007');
IF NOT EXISTS (SELECT 1 FROM dbo.PASSENGER WHERE PassportNumber=N'BG100008')
    INSERT INTO dbo.PASSENGER (FirstName, LastName, DateOfBirth, Nationality, PassportNumber)
    VALUES (N'Daria', N'Georgieva', '2000-03-17', N'Bulgarian', N'BG100008');
IF NOT EXISTS (SELECT 1 FROM dbo.PASSENGER WHERE PassportNumber=N'BG100009')
    INSERT INTO dbo.PASSENGER (FirstName, LastName, DateOfBirth, Nationality, PassportNumber)
    VALUES (N'Alex', N'Marinov', '1996-08-09', N'Bulgarian', N'BG100009');
IF NOT EXISTS (SELECT 1 FROM dbo.PASSENGER WHERE PassportNumber=N'BG100010')
    INSERT INTO dbo.PASSENGER (FirstName, LastName, DateOfBirth, Nationality, PassportNumber)
    VALUES (N'Iva', N'Petrova', '2002-12-30', N'Bulgarian', N'BG100010');

IF NOT EXISTS (SELECT 1 FROM dbo.FLIGHT WHERE FlightNumber = N'ES101')
    INSERT INTO dbo.FLIGHT (AirlineName, FlightNumber, Origin, Destination, DepartureTime, ArrivalTime, BasePrice)
    VALUES (N'eSky Demo Air', N'ES101', N'Sofia', N'Rome', '2027-05-10T08:00:00', '2027-05-10T09:30:00', 220.00);
IF NOT EXISTS (SELECT 1 FROM dbo.FLIGHT WHERE FlightNumber = N'ES202')
    INSERT INTO dbo.FLIGHT (AirlineName, FlightNumber, Origin, Destination, DepartureTime, ArrivalTime, BasePrice)
    VALUES (N'eSky Demo Air', N'ES202', N'Sofia', N'Paris', '2027-06-15T10:00:00', '2027-06-15T12:30:00', 280.00);
IF NOT EXISTS (SELECT 1 FROM dbo.FLIGHT WHERE FlightNumber = N'ES303')
    INSERT INTO dbo.FLIGHT (AirlineName, FlightNumber, Origin, Destination, DepartureTime, ArrivalTime, BasePrice)
    VALUES (N'eSky Demo Air', N'ES303', N'Sofia', N'London', '2027-07-01T07:30:00', '2027-07-01T09:45:00', 310.00);

IF NOT EXISTS (SELECT 1 FROM dbo.FLIGHT WHERE FlightNumber=N'ES404')
    INSERT INTO dbo.FLIGHT (AirlineName, FlightNumber, Origin, Destination, DepartureTime, ArrivalTime, BasePrice)
    VALUES (N'eSky Demo Air', N'ES404', N'Sofia', N'Barcelona', '2027-08-10T07:00:00', '2027-08-10T09:40:00', 250.00);
IF NOT EXISTS (SELECT 1 FROM dbo.FLIGHT WHERE FlightNumber=N'ES505')
    INSERT INTO dbo.FLIGHT (AirlineName, FlightNumber, Origin, Destination, DepartureTime, ArrivalTime, BasePrice)
    VALUES (N'eSky Demo Air', N'ES505', N'Sofia', N'Athens', '2027-08-20T08:10:00', '2027-08-20T10:00:00', 190.00);
IF NOT EXISTS (SELECT 1 FROM dbo.FLIGHT WHERE FlightNumber=N'ES606')
    INSERT INTO dbo.FLIGHT (AirlineName, FlightNumber, Origin, Destination, DepartureTime, ArrivalTime, BasePrice)
    VALUES (N'eSky Demo Air', N'ES606', N'Sofia', N'Istanbul', '2027-09-01T09:00:00', '2027-09-01T11:20:00', 240.00);
IF NOT EXISTS (SELECT 1 FROM dbo.FLIGHT WHERE FlightNumber=N'ES707')
    INSERT INTO dbo.FLIGHT (AirlineName, FlightNumber, Origin, Destination, DepartureTime, ArrivalTime, BasePrice)
    VALUES (N'eSky Demo Air', N'ES707', N'Sofia', N'Vienna', '2027-09-14T06:30:00', '2027-09-14T08:00:00', 205.00);
IF NOT EXISTS (SELECT 1 FROM dbo.FLIGHT WHERE FlightNumber=N'ES808')
    INSERT INTO dbo.FLIGHT (AirlineName, FlightNumber, Origin, Destination, DepartureTime, ArrivalTime, BasePrice)
    VALUES (N'eSky Demo Air', N'ES808', N'Sofia', N'Prague', '2027-10-05T07:15:00', '2027-10-05T09:00:00', 210.00);
IF NOT EXISTS (SELECT 1 FROM dbo.FLIGHT WHERE FlightNumber=N'ES909')
    INSERT INTO dbo.FLIGHT (AirlineName, FlightNumber, Origin, Destination, DepartureTime, ArrivalTime, BasePrice)
    VALUES (N'eSky Demo Air', N'ES909', N'Sofia', N'Lisbon', '2027-10-18T11:00:00', '2027-10-18T14:00:00', 225.00);
IF NOT EXISTS (SELECT 1 FROM dbo.FLIGHT WHERE FlightNumber=N'ES010')
    INSERT INTO dbo.FLIGHT (AirlineName, FlightNumber, Origin, Destination, DepartureTime, ArrivalTime, BasePrice)
    VALUES (N'eSky Demo Air', N'ES010', N'Sofia', N'Berlin', '2027-11-02T08:00:00', '2027-11-02T10:00:00', 230.00);

IF NOT EXISTS (SELECT 1 FROM dbo.HOTEL WHERE HotelName = N'Roma Centro')
    INSERT INTO dbo.HOTEL (HotelName, City, Country, StarRating, PricePerNight)
    VALUES (N'Roma Centro', N'Rome', N'Italy', 4, 120.00);
IF NOT EXISTS (SELECT 1 FROM dbo.HOTEL WHERE HotelName = N'Paris Lumiere')
    INSERT INTO dbo.HOTEL (HotelName, City, Country, StarRating, PricePerNight)
    VALUES (N'Paris Lumiere', N'Paris', N'France', 4, 150.00);
IF NOT EXISTS (SELECT 1 FROM dbo.HOTEL WHERE HotelName = N'London Bridge Hotel')
    INSERT INTO dbo.HOTEL (HotelName, City, Country, StarRating, PricePerNight)
    VALUES (N'London Bridge Hotel', N'London', N'United Kingdom', 3, 170.00);

IF NOT EXISTS (SELECT 1 FROM dbo.AMENITY WHERE AmenityName=N'Wi-Fi')
    INSERT INTO dbo.AMENITY (AmenityName, Category) VALUES (N'Wi-Fi', N'Internet');
IF NOT EXISTS (SELECT 1 FROM dbo.AMENITY WHERE AmenityName=N'Breakfast')
    INSERT INTO dbo.AMENITY (AmenityName, Category) VALUES (N'Breakfast', N'Food');
IF NOT EXISTS (SELECT 1 FROM dbo.AMENITY WHERE AmenityName=N'Parking')
    INSERT INTO dbo.AMENITY (AmenityName, Category) VALUES (N'Parking', N'Transport');
IF NOT EXISTS (SELECT 1 FROM dbo.AMENITY WHERE AmenityName=N'Swimming pool')
    INSERT INTO dbo.AMENITY (AmenityName, Category) VALUES (N'Swimming pool', N'Recreation');
IF NOT EXISTS (SELECT 1 FROM dbo.AMENITY WHERE AmenityName=N'Air conditioning')
    INSERT INTO dbo.AMENITY (AmenityName, Category) VALUES (N'Air conditioning', N'Comfort');
IF NOT EXISTS (SELECT 1 FROM dbo.AMENITY WHERE AmenityName=N'Pet friendly')
    INSERT INTO dbo.AMENITY (AmenityName, Category) VALUES (N'Pet friendly', N'Policy');

-- Add five sample hotels to provide more destinations and prices.
IF NOT EXISTS (SELECT 1 FROM dbo.HOTEL WHERE HotelName=N'Barcelona Beach')
    INSERT INTO dbo.HOTEL (HotelName, City, Country, StarRating, PricePerNight)
    VALUES (N'Barcelona Beach', N'Barcelona', N'Spain', 4, 110.00);
IF NOT EXISTS (SELECT 1 FROM dbo.HOTEL WHERE HotelName=N'Athens View')
    INSERT INTO dbo.HOTEL (HotelName, City, Country, StarRating, PricePerNight)
    VALUES (N'Athens View', N'Athens', N'Greece', 3, 90.00);
IF NOT EXISTS (SELECT 1 FROM dbo.HOTEL WHERE HotelName=N'Istanbul Bosphorus')
    INSERT INTO dbo.HOTEL (HotelName, City, Country, StarRating, PricePerNight)
    VALUES (N'Istanbul Bosphorus', N'Istanbul', N'Turkey', 5, 135.00);
IF NOT EXISTS (SELECT 1 FROM dbo.HOTEL WHERE HotelName=N'Vienna Central')
    INSERT INTO dbo.HOTEL (HotelName, City, Country, StarRating, PricePerNight)
    VALUES (N'Vienna Central', N'Vienna', N'Austria', 4, 120.00);
IF NOT EXISTS (SELECT 1 FROM dbo.HOTEL WHERE HotelName=N'Prague Old Town')
    INSERT INTO dbo.HOTEL (HotelName, City, Country, StarRating, PricePerNight)
    VALUES (N'Prague Old Town', N'Prague', N'Czechia', 3, 100.00);

-- Each hotel can offer many amenities; an amenity can belong to many hotels.
INSERT INTO dbo.HOTEL_AMENITY (HotelId, AmenityId)
SELECT h.HotelId, a.AmenityId
FROM (VALUES
    (N'Roma Centro', N'Wi-Fi'), (N'Roma Centro', N'Breakfast'), (N'Roma Centro', N'Parking'), (N'Roma Centro', N'Air conditioning'),
    (N'Paris Lumiere', N'Wi-Fi'), (N'Paris Lumiere', N'Breakfast'), (N'Paris Lumiere', N'Air conditioning'),
    (N'London Bridge Hotel', N'Wi-Fi'), (N'London Bridge Hotel', N'Parking'), (N'London Bridge Hotel', N'Air conditioning'),
    (N'Barcelona Beach', N'Wi-Fi'), (N'Barcelona Beach', N'Swimming pool'), (N'Barcelona Beach', N'Breakfast'),
    (N'Athens View', N'Wi-Fi'), (N'Athens View', N'Breakfast'), (N'Athens View', N'Pet friendly'),
    (N'Istanbul Bosphorus', N'Wi-Fi'), (N'Istanbul Bosphorus', N'Swimming pool'), (N'Istanbul Bosphorus', N'Air conditioning'),
    (N'Vienna Central', N'Wi-Fi'), (N'Vienna Central', N'Parking'), (N'Vienna Central', N'Breakfast'),
    (N'Prague Old Town', N'Wi-Fi'), (N'Prague Old Town', N'Parking'), (N'Prague Old Town', N'Pet friendly')
) AS v(HotelName, AmenityName)
JOIN dbo.HOTEL AS h ON h.HotelName = v.HotelName
JOIN dbo.AMENITY AS a ON a.AmenityName = v.AmenityName
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.HOTEL_AMENITY AS ha
    WHERE ha.HotelId = h.HotelId AND ha.AmenityId = a.AmenityId
);

UPDATE h SET AmenityCount = dbo.fn_HotelAmenityCount(h.HotelId)
FROM dbo.HOTEL AS h;

DECLARE @EUR INT = (SELECT CurrencyId FROM dbo.CURRENCY WHERE CurrencyCode = 'EUR');
DECLARE @Customer1 INT = (SELECT CustomerId FROM dbo.CUSTOMER WHERE Email = N'maria@example.com');
DECLARE @Customer2 INT = (SELECT CustomerId FROM dbo.CUSTOMER WHERE Email = N'georgi@example.com');
DECLARE @Customer3 INT = (SELECT CustomerId FROM dbo.CUSTOMER WHERE Email = N'elena@example.com');
DECLARE @Customer4 INT = (SELECT CustomerId FROM dbo.CUSTOMER WHERE Email=N'nina@example.com');
DECLARE @Customer5 INT = (SELECT CustomerId FROM dbo.CUSTOMER WHERE Email=N'petar@example.com');
DECLARE @Customer6 INT = (SELECT CustomerId FROM dbo.CUSTOMER WHERE Email=N'sara@example.com');
DECLARE @Customer7 INT = (SELECT CustomerId FROM dbo.CUSTOMER WHERE Email=N'viktor@example.com');
DECLARE @Customer8 INT = (SELECT CustomerId FROM dbo.CUSTOMER WHERE Email=N'daria@example.com');
DECLARE @Customer9 INT = (SELECT CustomerId FROM dbo.CUSTOMER WHERE Email=N'alex@example.com');
DECLARE @Customer10 INT = (SELECT CustomerId FROM dbo.CUSTOMER WHERE Email=N'iva@example.com');
DECLARE @Passenger1 INT = (SELECT PassengerId FROM dbo.PASSENGER WHERE PassportNumber = N'BG100001');
DECLARE @Passenger2 INT = (SELECT PassengerId FROM dbo.PASSENGER WHERE PassportNumber = N'BG100002');
DECLARE @Passenger3 INT = (SELECT PassengerId FROM dbo.PASSENGER WHERE PassportNumber = N'BG100003');
DECLARE @Passenger4 INT = (SELECT PassengerId FROM dbo.PASSENGER WHERE PassportNumber=N'BG100004');
DECLARE @Passenger5 INT = (SELECT PassengerId FROM dbo.PASSENGER WHERE PassportNumber=N'BG100005');
DECLARE @Passenger6 INT = (SELECT PassengerId FROM dbo.PASSENGER WHERE PassportNumber=N'BG100006');
DECLARE @Passenger7 INT = (SELECT PassengerId FROM dbo.PASSENGER WHERE PassportNumber=N'BG100007');
DECLARE @Passenger8 INT = (SELECT PassengerId FROM dbo.PASSENGER WHERE PassportNumber=N'BG100008');
DECLARE @Passenger9 INT = (SELECT PassengerId FROM dbo.PASSENGER WHERE PassportNumber=N'BG100009');
DECLARE @Passenger10 INT = (SELECT PassengerId FROM dbo.PASSENGER WHERE PassportNumber=N'BG100010');
DECLARE @Flight1 INT = (SELECT FlightId FROM dbo.FLIGHT WHERE FlightNumber = N'ES101');
DECLARE @Flight2 INT = (SELECT FlightId FROM dbo.FLIGHT WHERE FlightNumber = N'ES202');
DECLARE @Flight3 INT = (SELECT FlightId FROM dbo.FLIGHT WHERE FlightNumber = N'ES303');
DECLARE @Flight4 INT = (SELECT FlightId FROM dbo.FLIGHT WHERE FlightNumber=N'ES404');
DECLARE @Flight5 INT = (SELECT FlightId FROM dbo.FLIGHT WHERE FlightNumber=N'ES505');
DECLARE @Flight6 INT = (SELECT FlightId FROM dbo.FLIGHT WHERE FlightNumber=N'ES606');
DECLARE @Flight7 INT = (SELECT FlightId FROM dbo.FLIGHT WHERE FlightNumber=N'ES707');
DECLARE @Flight8 INT = (SELECT FlightId FROM dbo.FLIGHT WHERE FlightNumber=N'ES808');
DECLARE @Flight9 INT = (SELECT FlightId FROM dbo.FLIGHT WHERE FlightNumber=N'ES909');
DECLARE @Flight10 INT = (SELECT FlightId FROM dbo.FLIGHT WHERE FlightNumber=N'ES010');
DECLARE @Hotel1 INT = (SELECT HotelId FROM dbo.HOTEL WHERE HotelName = N'Roma Centro');
DECLARE @Hotel2 INT = (SELECT HotelId FROM dbo.HOTEL WHERE HotelName = N'Paris Lumiere');
DECLARE @Hotel3 INT = (SELECT HotelId FROM dbo.HOTEL WHERE HotelName = N'London Bridge Hotel');
DECLARE @Hotel4 INT = (SELECT HotelId FROM dbo.HOTEL WHERE HotelName=N'Barcelona Beach');
DECLARE @Hotel5 INT = (SELECT HotelId FROM dbo.HOTEL WHERE HotelName=N'Athens View');
DECLARE @Hotel6 INT = (SELECT HotelId FROM dbo.HOTEL WHERE HotelName=N'Istanbul Bosphorus');
DECLARE @Hotel7 INT = (SELECT HotelId FROM dbo.HOTEL WHERE HotelName=N'Vienna Central');
DECLARE @Hotel8 INT = (SELECT HotelId FROM dbo.HOTEL WHERE HotelName=N'Prague Old Town');

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
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-004')
    INSERT INTO dbo.BOOKING (CustomerId, FlightId, HotelId, CurrencyId, BookingReference, DepartureDate, ReturnDate, TotalAmount)
    VALUES (@Customer4, @Flight4, @Hotel4, @EUR, N'ESKY-2027-004', '2027-08-10', '2027-08-14', 0);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-005')
    INSERT INTO dbo.BOOKING (CustomerId, FlightId, HotelId, CurrencyId, BookingReference, DepartureDate, ReturnDate, TotalAmount)
    VALUES (@Customer5, @Flight5, @Hotel5, @EUR, N'ESKY-2027-005', '2027-08-20', '2027-08-25', 0);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-006')
    INSERT INTO dbo.BOOKING (CustomerId, FlightId, HotelId, CurrencyId, BookingReference, DepartureDate, ReturnDate, TotalAmount)
    VALUES (@Customer6, @Flight6, @Hotel6, @EUR, N'ESKY-2027-006', '2027-09-01', '2027-09-04', 0);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-007')
    INSERT INTO dbo.BOOKING (CustomerId, FlightId, HotelId, CurrencyId, BookingReference, DepartureDate, ReturnDate, TotalAmount)
    VALUES (@Customer7, @Flight7, @Hotel7, @EUR, N'ESKY-2027-007', '2027-09-14', '2027-09-16', 0);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-008')
    INSERT INTO dbo.BOOKING (CustomerId, FlightId, HotelId, CurrencyId, BookingReference, DepartureDate, ReturnDate, TotalAmount)
    VALUES (@Customer8, @Flight8, @Hotel8, @EUR, N'ESKY-2027-008', '2027-10-05', '2027-10-08', 0);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-009')
    INSERT INTO dbo.BOOKING (CustomerId, FlightId, HotelId, CurrencyId, BookingReference, DepartureDate, ReturnDate, BookingStatus, TotalAmount)
    VALUES (@Customer9, @Flight9, NULL, @EUR, N'ESKY-2027-009', '2027-10-18', '2027-10-23', N'Cancelled', 0);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-010')
    INSERT INTO dbo.BOOKING (CustomerId, FlightId, HotelId, CurrencyId, BookingReference, DepartureDate, ReturnDate, TotalAmount)
    VALUES (@Customer10, @Flight10, NULL, @EUR, N'ESKY-2027-010', '2027-11-02', '2027-11-04', 0);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-011')
    INSERT INTO dbo.BOOKING (CustomerId, FlightId, HotelId, CurrencyId, BookingReference, DepartureDate, ReturnDate, TotalAmount)
    VALUES (@Customer4, @Flight2, @Hotel2, @EUR, N'ESKY-2027-011', '2027-06-15', '2027-06-17', 0);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-012')
    INSERT INTO dbo.BOOKING (CustomerId, FlightId, HotelId, CurrencyId, BookingReference, DepartureDate, ReturnDate, TotalAmount)
    VALUES (@Customer1, @Flight6, @Hotel6, @EUR, N'ESKY-2027-012', '2027-09-01', '2027-09-04', 0);


DECLARE @Booking1 INT = (SELECT BookingId FROM dbo.BOOKING WHERE BookingReference = N'ESKY-2027-001');
DECLARE @Booking2 INT = (SELECT BookingId FROM dbo.BOOKING WHERE BookingReference = N'ESKY-2027-002');
DECLARE @Booking3 INT = (SELECT BookingId FROM dbo.BOOKING WHERE BookingReference = N'ESKY-2027-003');
DECLARE @Booking4 INT = (SELECT BookingId FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-004');
DECLARE @Booking5 INT = (SELECT BookingId FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-005');
DECLARE @Booking6 INT = (SELECT BookingId FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-006');
DECLARE @Booking7 INT = (SELECT BookingId FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-007');
DECLARE @Booking8 INT = (SELECT BookingId FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-008');
DECLARE @Booking9 INT = (SELECT BookingId FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-009');
DECLARE @Booking10 INT = (SELECT BookingId FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-010');
DECLARE @Booking11 INT = (SELECT BookingId FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-011');
DECLARE @Booking12 INT = (SELECT BookingId FROM dbo.BOOKING WHERE BookingReference=N'ESKY-2027-012');

IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking1 AND PassengerId=@Passenger1)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking1, @Passenger1);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking2 AND PassengerId=@Passenger2)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking2, @Passenger2);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking3 AND PassengerId=@Passenger3)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking3, @Passenger3);

IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking4 AND PassengerId=@Passenger4)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking4, @Passenger4);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking5 AND PassengerId=@Passenger5)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking5, @Passenger5);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking6 AND PassengerId=@Passenger6)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking6, @Passenger6);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking7 AND PassengerId=@Passenger7)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking7, @Passenger7);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking8 AND PassengerId=@Passenger8)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking8, @Passenger8);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking9 AND PassengerId=@Passenger9)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking9, @Passenger9);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking10 AND PassengerId=@Passenger10)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking10, @Passenger10);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking11 AND PassengerId=@Passenger4)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking11, @Passenger4);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking11 AND PassengerId=@Passenger5)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking11, @Passenger5);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking12 AND PassengerId=@Passenger1)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking12, @Passenger1);
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_PASSENGER WHERE BookingId=@Booking12 AND PassengerId=@Passenger3)
    INSERT INTO dbo.BOOKING_PASSENGER (BookingId, PassengerId) VALUES (@Booking12, @Passenger3);

-- Refresh totals for all sample bookings after the complete seed data is present.
UPDATE b SET TotalAmount = dbo.fn_BookingTotal(b.BookingId)
FROM dbo.BOOKING AS b
WHERE b.BookingReference BETWEEN N'ESKY-2027-001' AND N'ESKY-2027-012';

IF NOT EXISTS (SELECT 1 FROM dbo.PAYMENT WHERE BookingId=@Booking1 AND PaymentStatus=N'Succeeded')
    INSERT INTO dbo.PAYMENT (BookingId, Amount, PaymentMethod, PaymentStatus)
    VALUES (@Booking1, 580.00, N'Card', N'Succeeded');
IF NOT EXISTS (SELECT 1 FROM dbo.PAYMENT WHERE BookingId=@Booking2 AND PaymentStatus=N'Succeeded')
    INSERT INTO dbo.PAYMENT (BookingId, Amount, PaymentMethod, PaymentStatus)
    VALUES (@Booking2, 300.00, N'Card', N'Succeeded');
IF NOT EXISTS (SELECT 1 FROM dbo.PAYMENT WHERE BookingId=@Booking3 AND PaymentStatus=N'Failed')
    INSERT INTO dbo.PAYMENT (BookingId, Amount, PaymentMethod, PaymentStatus)
    VALUES (@Booking3, 820.00, N'Card', N'Failed');

IF NOT EXISTS (SELECT 1 FROM dbo.PAYMENT WHERE BookingId=@Booking4)
    INSERT INTO dbo.PAYMENT (BookingId, Amount, PaymentMethod, PaymentStatus)
    SELECT @Booking4, TotalAmount, N'Card', N'Succeeded' FROM dbo.BOOKING WHERE BookingId=@Booking4;
IF NOT EXISTS (SELECT 1 FROM dbo.PAYMENT WHERE BookingId=@Booking5)
    INSERT INTO dbo.PAYMENT (BookingId, Amount, PaymentMethod, PaymentStatus)
    SELECT @Booking5, TotalAmount, N'PayPal', N'Succeeded' FROM dbo.BOOKING WHERE BookingId=@Booking5;
IF NOT EXISTS (SELECT 1 FROM dbo.PAYMENT WHERE BookingId=@Booking6)
    INSERT INTO dbo.PAYMENT (BookingId, Amount, PaymentMethod, PaymentStatus)
    VALUES (@Booking6, 200.00, N'Card', N'Succeeded');
IF NOT EXISTS (SELECT 1 FROM dbo.PAYMENT WHERE BookingId=@Booking7)
    INSERT INTO dbo.PAYMENT (BookingId, Amount, PaymentMethod, PaymentStatus)
    SELECT @Booking7, TotalAmount, N'Bank transfer', N'Succeeded' FROM dbo.BOOKING WHERE BookingId=@Booking7;
IF NOT EXISTS (SELECT 1 FROM dbo.PAYMENT WHERE BookingId=@Booking8)
    INSERT INTO dbo.PAYMENT (BookingId, Amount, PaymentMethod, PaymentStatus)
    SELECT @Booking8, TotalAmount, N'Card', N'Failed' FROM dbo.BOOKING WHERE BookingId=@Booking8;
IF NOT EXISTS (SELECT 1 FROM dbo.PAYMENT WHERE BookingId=@Booking10)
    INSERT INTO dbo.PAYMENT (BookingId, Amount, PaymentMethod, PaymentStatus)
    SELECT @Booking10, TotalAmount, N'PayPal', N'Succeeded' FROM dbo.BOOKING WHERE BookingId=@Booking10;
IF NOT EXISTS (SELECT 1 FROM dbo.PAYMENT WHERE BookingId=@Booking11)
    INSERT INTO dbo.PAYMENT (BookingId, Amount, PaymentMethod, PaymentStatus)
    VALUES (@Booking11, 50.00, N'Card', N'Succeeded');
IF NOT EXISTS (SELECT 1 FROM dbo.PAYMENT WHERE BookingId=@Booking12)
    INSERT INTO dbo.PAYMENT (BookingId, Amount, PaymentMethod, PaymentStatus)
    SELECT @Booking12, TotalAmount, N'Bank transfer', N'Succeeded' FROM dbo.BOOKING WHERE BookingId=@Booking12;
GO

-- Quick presentation queries
SELECT BookingReference, BookingStatus, TotalAmount FROM dbo.BOOKING ORDER BY BookingId;
SELECT HotelName, City, StarRating, AmenityCount FROM dbo.HOTEL ORDER BY HotelName;
SELECT h.HotelName, a.AmenityName
FROM dbo.HOTEL_AMENITY AS ha
JOIN dbo.HOTEL AS h ON h.HotelId = ha.HotelId
JOIN dbo.AMENITY AS a ON a.AmenityId = ha.AmenityId
ORDER BY h.HotelName, a.AmenityName;
SELECT dbo.fn_BookingTotal(BookingId) AS CalculatedTotal, BookingReference FROM dbo.BOOKING ORDER BY BookingId;


