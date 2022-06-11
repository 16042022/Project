use Portfolio_Project;

/*** Cleaning data in SQL Queries ***/

select top(10) *
from dbo.naville_house;

---- Standardize Date format ----

select TOP(10) *
from dbo.naville_house;

--- alter table naville_house
--- add sale_date Date;

--- Add a new column, add add its value by value of SaleDate data was converted
--- Press Ctrl + Shift + R to refresh intellisense (refresh the query interface)
update naville_house
set sale_date = convert(Date, SaleDate);

---- Populate Property Address ----
--- Problem: When check data with condition is null, the PropertyAdresss have some missing value records
with check_null as
(select ParcelID
from naville_house
where PropertyAddress is null),

-- Check for duplicate data----
field_dup as
(select 
	ParcelID, 
	count(*) as occur
from naville_house
group by ParcelID
having count(*) > 1)

select cn.ParcelID, fd.ParcelID
from check_null cn
left join field_dup fd
on cn.ParcelID = fd.ParcelID

--- Result: for each missed records in Property Adress, it will be the one item being duplicated----
--- That's true for when we check by all item of data, some records seemed to be duplicated-----
select *
from naville_house
order by ParcelID

--- Because there's have duplicate for missed records, we will use those duplicated item to fill in the hole---
--- To do that, we know the duplicated items just another external records => If we self join, the problem is done---
--- Join condition: same Parcell ID but differ UniqueID---
select nh1.ParcelID, nh1.PropertyAddress, 
	nh2.ParcelID, nh2.PropertyAddress, ISNULL(nh1.PropertyAddress, nh2.PropertyAddress)
from naville_house nh1
inner join naville_house nh2
on nh1.ParcelID = nh2.ParcelID
and nh1.[UniqueID ] <> nh2.[UniqueID ]
where nh1.PropertyAddress is null

--- To update, we will Update with FROM clause:
/*
update nh1 
set PropertyAddress = ISNULL(nh1.PropertyAddress, nh2.PropertyAddress)
from naville_house nh1
inner join naville_house nh2
on nh1.ParcelID = nh2.ParcelID
and nh1.[UniqueID ] <> nh2.[UniqueID ]
where nh1.PropertyAddress is null 
*/

-- Check data again---
select *
from naville_house
where PropertyAddress is null
-- The missed records was all done => We have fill in succesfully------

----- Breaking the Address data into Invidual field (Address, City, State)-----------

--- Select a few records ---
select top(10) *
from naville_house

select 
	SUBSTRING(PropertyAddress, 1, CHARINDEX(',',PropertyAddress)-1) as adress,
	SUBSTRING(PropertyAddress, CHARINDEX(',',PropertyAddress)+1, LEN(PropertyAddress)-CHARINDEX(',',PropertyAddress)+1) as city
from naville_house
--- Idea: Because name's construc is: Adress, City, State that could be align with concept: Server.DB.Schema.Obj---
--- => Change ',' syntax to '.' syntax, and parse this name into piece that we want----
select 
	parsename(replace(OwnerAddress, ',', '.'),3) as state_,
	parsename(replace(OwnerAddress, ',', '.'),2) as city_,
	parsename(replace(OwnerAddress, ',', '.'),1) as address_
from naville_house

--- Update result---
--- For PropertyAddress ---
/*
alter table naville_house
add prop_add Nvarchar(255),
	prop_city Nvarchar(255),
	owner_add Nvarchar(255),
	owner_city Nvarchar(255),
	owner_state Nvarchar(255);
*/

/*
update naville_house
set prop_add = SUBSTRING(PropertyAddress, 1, CHARINDEX(',',PropertyAddress)-1),
	prop_city = SUBSTRING(PropertyAddress, CHARINDEX(',',PropertyAddress)+1, LEN(PropertyAddress)-CHARINDEX(',',PropertyAddress)+1),
	owner_add = parsename(replace(OwnerAddress, ',', '.'),3),
	owner_city = parsename(replace(OwnerAddress, ',', '.'),2),
	owner_state = parsename(replace(OwnerAddress, ',', '.'),1);
*/
-------- Change Y and N to Yes and No in 'Sold As Vacant'--------------
select distinct (SoldAsVacant), count(SoldAsVacant)
from naville_house
group by SoldAsVacant
order by 2;

select 
	CASE
		WHEN SoldAsVacant = 'N' Then 'No'
		When SoldAsVacant = 'Y' THEN 'Yes'
		ELSE SoldAsVacant
	END
from naville_house;

/*
update naville_house
set SoldAsVacant = CASE
		WHEN SoldAsVacant = 'N' Then 'No'
		When SoldAsVacant = 'Y' THEN 'Yes'
		ELSE SoldAsVacant
	END
*/
----- Check missing value of address field----
with check_null_2 as
(select ParcelID, owner_add
from naville_house
where owner_add is null),

-- Check for duplicate data----
field_dup_2 as
(select 
	ParcelID,
	count(*) as occur
from naville_house
group by ParcelID
having count(*) > 1)

select cn2.ParcelID, cn2.owner_add, fd2.ParcelID
from check_null_2 cn2
left join field_dup_2 fd2
on cn2.ParcelID = fd2.ParcelID
-- Result: 1. The number of duplicated and missing records from both duplicate table and check null table is large (8343 rows)--
-- 2. Have some records that not duplicate but still null => We will check the co-response value by self join below--

-- Check 2 (Just for optional, not nesscessary): If ParcelID of records where owner_add is not null, have it duplicate?
with check_not_null as
(select ParcelID, owner_add
from naville_house
where owner_add is not null),

-- Check for duplicate data----
field_dup_2 as
(select 
	ParcelID, 
	count(*) as occur
from naville_house
group by ParcelID
having count(*) > 1)

select cnn.ParcelID, cnn.owner_add, fd2.ParcelID, occur
from check_not_null cnn
left join field_dup_2 fd2
on cnn.ParcelID = fd2.ParcelID
where occur >= 2

--- Result: Both none null and null records have its duplicate => before remove the duplicate, we will fill in the missing value
-- of OwnerAddress

select nh1.ParcelID, nh1.owner_add, nh1.owner_city, nh1.owner_state, 
	nh2.ParcelID, nh2.owner_add, nh2.owner_city, nh2.owner_state
from naville_house nh1
inner join naville_house nh2
on nh1.ParcelID = nh2.ParcelID
and nh1.[UniqueID ] <> nh2.[UniqueID ]
where nh1.owner_add is null;

-- When check by self join, at the same ParcelID, there's no coresponse value for each missing records of owner field --
-- => In this scope of project, we will drop all the duplicate above because there's not any value for missied records --
------- Removing duplicate --------------

with check_dup as
(select 
	*,
	ROW_NUMBER () Over (
	PARTITION BY ParcelID, PropertyAddress, SaleDate, SalePrice, LegalReference
	ORDER BY ParcelID, PropertyAddress, SaleDate, SalePrice, LegalReference) as row_num
from naville_house)
/*
delete 
from check_dup
where row_num > 1
*/
select *
from check_dup
where row_num > 1;

------- Delete un-used column (Practise) ------------

--- We won't delete unused column, instead, we will just query what field we want, and let other remain---
--- Like we mentioned in the previous that all the remain missing have no value to fill by duplicated records, so while extract it,---
--- we will consider what kind to fill in these missing value, or take data from somewhere else, etc.. later---
