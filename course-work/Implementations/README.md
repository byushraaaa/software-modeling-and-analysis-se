# eSky.com — coursework project

**Faculty number:** 2401321069  
**Project:** eSky travel booking database and Power BI report

## Description

A small educational travel booking model inspired by eSky.com. Customers book flights, may add hotels, connect passengers to bookings, and make payments. The project includes an operational SQL database, conceptual and logical diagrams, a Data Warehouse model, and a Power BI report.

## Project structure

- `SQL/eSkyCoursework.sql` — creates the database, 10 tables, and sample data.
- `diagrams/eSky_Database_Diagrams.drawio` — source diagram with Chen conceptual, Crow’s Foot logical, and Data Warehouse UML pages.
- `diagrams/eSky_Conceptual_Model_Chen.png` — conceptual model export.
- `diagrams/eSky_Logical_Model_Crows_Foot.png` — logical model export.
- `diagrams/eSky_Data_Warehouse_UML.png` — Data Warehouse model export.
- `Power BI/eSky_Power_BI_Report.pbix` — Power BI report.
- `Power BI/Booking_Amount_by_Destination.jpg` — booking amount by destination.
- `Power BI/Passengers_by_Destination.jpg` — passenger count by destination.
- `Power BI/Booking_Amount_by_Status.jpg` — booking amount by status.
- `eSky_business_requirements.md` — project business requirements.

## Database contents

The operational database has 10 tables and 55 attributes. It has two many-to-many relationships: bookings and passengers, and hotels and amenities. The script includes 3 stored procedures, 2 functions, 3 triggers, and sample records for 12 bookings.

## Requirements

- SQL Server 2019 or later (LocalDB is sufficient)
- SQL Server Management Studio
- Power BI Desktop
- diagrams.net (optional, to view or edit diagrams)

## Installation and use

1. Open `SQL/eSkyCoursework.sql` in SQL Server Management Studio.
2. Connect to `(localdb)\MSSQLLocalDB` using Windows Authentication, or select another local SQL Server instance.
3. Execute the full script. It creates or updates `eSkyCoursework` and loads the sample data.
4. Open `Power BI/eSky_Power_BI_Report.pbix` in Power BI Desktop. If asked for credentials, choose **Windows → Use my current credentials** and select database `eSkyCoursework`.
5. Open `diagrams/eSky_Database_Diagrams.drawio` in diagrams.net to view or edit the models.

## Simple presentation notes

- `BOOKING_PASSENGER` links bookings and passengers; a booking can include several passengers, and a passenger can appear in more than one booking.
- `HOTEL_AMENITY` links hotels and amenities such as Wi-Fi, breakfast, and parking.
- The procedures create a booking, add a passenger, and add a hotel amenity.
- The functions calculate a booking total and count a hotel’s amenities.
- The triggers initialize booking totals, update booking status after payments, and maintain hotel amenity counts.
- The Power BI page compares booking value by destination, passenger count by destination, and booking value by status.

## Data Warehouse

The Data Warehouse model has three fact tables (`FactBooking`, `FactPayment`, and `FactServiceSale`) and seven dimensions (`DimDate`, `DimCustomer`, `DimDestination`, `DimCurrency`, `DimStatus`, `DimService`, and `DimSupplier`).
