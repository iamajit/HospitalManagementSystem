-- Hospital Management System Advanced SQL Queries
-- Tables assumed: Patients, Doctors, Beds, Admissions, Surgeries, Billing
-- -------------------------------------------------------------------------
--1.Find Top 5 doctors by total revenue generated (from billing + surgeries)

--Method 1
SELECT    top 5    dbo.Doctors.doctor_id, dbo.Doctors.first_name, dbo.Doctors.last_name
,SUM( dbo.Billing.consultation_fee+ dbo.Billing.surgery_charges) as TotalRevenue
FROM dbo.Billing INNER JOIN
dbo.Admissions ON dbo.Billing.admission_id = dbo.Admissions.admission_id INNER JOIN
dbo.Doctors ON dbo.Admissions.doctor_id = dbo.Doctors.doctor_id
group by dbo.Doctors.doctor_id, dbo.Doctors.first_name, dbo.Doctors.last_name
order by SUM( dbo.Billing.consultation_fee+ dbo.Billing.surgery_charges) desc;

--Method 2
 WITH doctor_revenue AS (
    SELECT d.doctor_id, d.first_name, d.last_name,
           SUM(b.consultation_fee + b.surgery_charges) AS total_revenue
    FROM Doctors d
    JOIN Admissions a ON d.doctor_id = a.doctor_id
    JOIN Billing b ON a.admission_id = b.admission_id
    GROUP BY d.doctor_id, d.first_name, d.last_name
)
SELECT TOP 5 * 
FROM doctor_revenue
ORDER BY total_revenue DESC;

/* 2) Longest hospital stays: top 10 patients by stay length */

SELECT   top  10    dbo.Patients.patient_id, dbo.Patients.first_name, dbo.Patients.last_name
,DATEDIFF(dd, dbo.Admissions.admit_date, dbo.Admissions.discharge_date) as NoOfDaysStay
FROM dbo.Admissions INNER JOIN
dbo.Patients ON dbo.Admissions.patient_id = dbo.Patients.patient_id
where discharge_date is not null
order by NoOfDaysStay desc

/* 3) Average age of patients per diagnosis */


SELECT        dbo.Admissions.diagnosis,AVG( dbo.Patients.age) as AvgAge
FROM            dbo.Admissions INNER JOIN
dbo.Patients ON dbo.Admissions.patient_id = dbo.Patients.patient_id
group by dbo.Admissions.diagnosis
order by AvgAge desc

/* 4) Doctors with the highest number of emergency admissions */

SELECT   top 20     dbo.Doctors.doctor_id, dbo.Doctors.first_name, dbo.Doctors.last_name,COUNT( dbo.Admissions.admission_priority) as NoOfEmergency
FROM            dbo.Admissions INNER JOIN
                         dbo.Doctors ON dbo.Admissions.doctor_id = dbo.Doctors.doctor_id
WHERE        (dbo.Admissions.admission_priority = N'Emergency')
group by  dbo.Doctors.doctor_id, dbo.Doctors.first_name, dbo.Doctors.last_name
order by NoOfEmergency desc,dbo.Doctors.doctor_id asc

/* 5) top 10 Doctors with highest avg admissions per month */

SELECT  top 10      dbo.Doctors.doctor_id, dbo.Doctors.first_name, dbo.Doctors.last_name
,  ROUND((COUNT(dbo.Admissions.admission_id)/ cast( COUNT(distinct format(dbo.Admissions.admit_date,'yyMM')) as decimal(8,2))),2) as AvgMonthlyadmission
FROM            dbo.Admissions INNER JOIN
dbo.Doctors ON dbo.Admissions.doctor_id = dbo.Doctors.doctor_id
group by dbo.Doctors.doctor_id, dbo.Doctors.first_name, dbo.Doctors.last_name
order by AvgMonthlyadmission desc

/* 6) Average daily bed revenue by ward */

SELECT        ward_type, AVG(daily_charge + nursing_charge) as Avg_Bed_Cost
FROM            dbo.Beds
group by ward_type
order by AVG(daily_charge + nursing_charge) desc

 /* 7) Top 10 beds with maximum re-assignments */
SELECT top 10 bed_id, COUNT(admission_id) AS times_used
FROM Admissions
GROUP BY bed_id
ORDER BY times_used DESC

/* 8) Avg delay in surgeries (actual vs estimated) */
SELECT type,
       AVG(actual_duration - estimated_duration) AS avg_delay
FROM Surgeries
WHERE status = 'Completed'
GROUP BY type
ORDER BY avg_delay DESC;

/* 9) Most common anesthesia type by department */
SELECT dept.department, srg.anesthesia_type, COUNT(srg.surgery_id) AS usage_count
FROM Surgeries srg
JOIN Doctors dept ON srg.doctor_id = dept.doctor_id
GROUP BY dept.department, srg.anesthesia_type
ORDER BY dept.department,usage_count DESC;

/* 10) Patients with unpaid bills above 50000 */

SELECT        dbo.Patients.patient_id, dbo.Patients.first_name, dbo.Patients.last_name,SUM( dbo.Billing.out_of_pocket) as UnpaidAmount
FROM            dbo.Patients INNER JOIN
                         dbo.Billing ON dbo.Patients.patient_id = dbo.Billing.patient_id
WHERE        (dbo.Billing.status = N'pending') --and dbo.Patients.patient_id='2'
group by dbo.Patients.patient_id, dbo.Patients.first_name, dbo.Patients.last_name
having SUM( dbo.Billing.out_of_pocket) > 50000
order by UnpaidAmount desc

/* 11) Insurance claim ratio by provider */

SELECT        Patients.insurance_provider AS InsuranceProvider, SUM(Billing.insurance_claim) AS TotalClaim, SUM(Billing.out_of_pocket) AS PaidByPatient
 ,CAST(SUM(Billing.insurance_claim) * 100.0 / SUM(Billing.insurance_claim + Billing.out_of_pocket) AS DECIMAL(5,2)) AS claim_ratio
FROM            Billing INNER JOIN
                         Patients ON Billing.patient_id = Patients.patient_id
GROUP BY Patients.insurance_provider

/* 12) Yearly admission growth rate */
SELECT YEAR(admit_date) AS year, COUNT(admission_id) AS admissions,
       LAG(COUNT(admission_id)) OVER (ORDER BY YEAR(admit_date)) AS prev_year,
       (COUNT(admission_id) - LAG(COUNT(admission_id)) OVER (ORDER BY YEAR(admit_date))) * 100.0 / NULLIF(LAG(COUNT(admission_id)) OVER (ORDER BY YEAR(admit_date)),0) AS growth_rate
FROM Admissions
GROUP BY YEAR(admit_date)
ORDER BY year;

/* 13) Patients treated by more than 5 different doctors */

SELECT        Admissions.patient_id, Patients.first_name, Patients.last_name, Patients.age, COUNT(DISTINCT Admissions.doctor_id) AS doctor_count
FROM            Admissions INNER JOIN
                         Patients ON Admissions.patient_id = Patients.patient_id
GROUP BY Admissions.patient_id, Patients.first_name, Patients.last_name, Patients.age
HAVING        (COUNT(DISTINCT Admissions.doctor_id) > 5)
order by doctor_count desc

/* 14) Longest gap between admissions for a patient */
WITH patient_visits AS (
  SELECT Admissions.patient_id,Patients.first_name,Patients.last_name,Patients.age, admit_date,
         LAG(admit_date) OVER (PARTITION BY Admissions.patient_id ORDER BY admit_date) AS prev_visit
  FROM Admissions INNER JOIN
                         Patients ON Admissions.patient_id = Patients.patient_id
)
SELECT patient_id,first_name,last_name,Age, MAX(DATEDIFF(DAY, prev_visit, admit_date)) AS max_gap_days
FROM patient_visits
WHERE prev_visit IS NOT NULL
GROUP BY patient_id,first_name,last_name,Age
ORDER BY max_gap_days DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;

/* 15) Doctors with consultation fee above department average(2 doctors with each department) */
with CTEDoctorFee as (
SELECT d.doctor_id, d.first_name, d.last_name, d.department, d.consultation_fee,tbl.dept_avg_fee
,RANK() over(partition by d.department order by d.consultation_fee desc) as RNK
FROM Doctors d
JOIN (
    SELECT department, AVG(consultation_fee) AS dept_avg_fee
    FROM Doctors
    GROUP BY department
) tbl ON d.department = tbl.department
WHERE d.consultation_fee > tbl.dept_avg_fee
--order by d.department,  d.consultation_fee desc
)
select  doctor_id,  first_name,  last_name,  department,  consultation_fee, dept_avg_fee from CTEDoctorFee where RNK<3

/* 16) Top 10 admissions by highest billing amount */
SELECT TOP 10 b.admission_id, p.first_name, p.last_name
, (b.consultation_fee+b.bed_charges+b.surgery_charges+b.pharmacy_charges+b.miscellaneous) AS total_amount
FROM Billing b
JOIN Admissions a ON b.admission_id = a.admission_id
JOIN Patients p ON a.patient_id = p.patient_id
ORDER BY total_amount DESC;

/* 17) Surgical success rate by doctor */
SELECT doc.doctor_id, doc.first_name, doc.last_name,
       SUM(CASE WHEN srg.outcome = 'Successful' THEN 1 ELSE 0 END) * 100.0 / COUNT(srg.surgery_id) AS success_rate
FROM Doctors doc
JOIN Surgeries srg ON doc.doctor_id = srg.doctor_id
GROUP BY doc.doctor_id, doc.first_name, doc.last_name
order by success_rate desc
offset 0 rows fetch next 10 rows only

 /* 18) Top 5 doctors by number of surgeries performed */
SELECT TOP 5 doc.doctor_id, doc.first_name, doc.last_name, COUNT(srg.surgery_id) AS total_surgeries
FROM Doctors doc
JOIN Surgeries srg ON doc.doctor_id = srg.doctor_id
GROUP BY doc.doctor_id, doc.first_name, doc.last_name
ORDER BY total_surgeries DESC;






 