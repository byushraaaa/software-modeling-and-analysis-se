# eSky.com — coursework project

**Faculty number:** 2401321069

## Short description

A small educational travel-booking database inspired by eSky.com. A customer books one flight and may add one hotel, adds one or more passengers, and pays for the booking.

## Included database objects

- 8 tables and 49 attributes
- A many-to-many Booking/Passenger link through `BOOKING_PASSENGER`
- Three sample bookings with confirmed, partly paid, and pending statuses
- `dbo.usp_CreateBooking` stored procedure
- `dbo.fn_BookingTotal` scalar function
- `dbo.trg_Payment_UpdateBookingStatus` trigger
- `eSky Power BI Report.pbix` Power BI report
- `eSky_Conceptual_and_Logical.drawio` Chen conceptual and Crow's Foot logical models
- `eSky_DW_Model.drawio` UML-style Data Warehouse model (3 facts and 6 dimensions)

## Requirements

- SQL Server 2019 or later (LocalDB is sufficient)
- SQL Server Management Studio
- Power BI Desktop

## Run the database

1. Open `eSkyCoursework.sql` in SSMS.
2. Connect to a local SQL Server instance.
3. Run the whole script with **Execute**.
4. The script creates the `eSkyCoursework` database, its tables and sample rows.

## Simple explanation for presentation

- The tables store customers, passengers, flights, hotels, currencies, bookings and payments.
- `BOOKING_PASSENGER` connects bookings and passengers because each can be linked to several of the other.
- The function adds the flight price and hotel price for the number of nights.
- The stored procedure creates a booking and links its first passenger.
- The trigger updates the booking status when a payment succeeds or is refunded.

## Data Warehouse

The simple star schema contains `FactBooking`, `FactPayment`, and `FactPassenger`. Its six dimensions are `DimDate`, `DimCustomer`, `DimDestination`, `DimCurrency`, `DimStatus`, and `DimTravelProduct`. Open `eSky_DW_Model.drawio` in draw.io.

## Power BI report

Open `eSky Power BI Report.pbix` in Power BI Desktop. The report includes a pie chart of booking amount by status, a column chart of amount by year, and a booking-date table. It uses the local `eSkyCoursework` database. If Power BI asks for connection details, use server `(localdb)\mssqllocaldb`, database `eSkyCoursework`, and **Windows → Use my current credentials**. A Microsoft account sign-in is not needed for this local report.
