### Materialized View
visit_level_conversions

### Description
For any screening mammogram visit, this table will indicate the type of conversion for that visit.

### Date of Creation
02/22/2019

### Dependencies
N/A

### Materialized View Detail

| Field Name | Description | Calculation |
|---|---|---|
| ID | This is the id from campaign_campaignstagecustomerresponse and is the unique identifier for individual campaign communication attempts | campaign_campaignstagecustomerresponse.id |
| VISIT_ID | This is the id from visit_visit and is the unique identifier for the mammogram visit | visit_visit.id |
| CUSTOMER_ID | This is the id from customer_customer and is the unique identifier for the customer | customer_customer.id |
| FIRST_NAME | This is the customer's first name | customer_customer.first_name |
| LAST_NAME | This is the customer's last name | customer_customer.last_name |
| DATE_OF_VISIT | This is the date of the mammogram appointment. This could be a date in the past (completed appointments) or a date in the future (scheduled appointments) | visit_visit.date_of_visit |
| BOOKED_AT | This is the date that the mammogram appointment was booked. | visit_visit.booked_at |
| CAMPAIGN_ID | This is the id from campaign_campaign and is the unique identifier for the communication campaign | campaign_campaignstagecustomerresponse.campaign_id |
| MRN | This is the customer's MRN | customer_customer.mrn |
| PDI_IND | This is indicates if the customer is a PDI customer. This makes it easy to create filters on. | case when customer_customer.clinic_group = 1 then 1 else 0 end |
| AZTECH_IND | This is indicates if the customer is an AZTech customer. This makes it easy to create filters on. | case when customer_customer.clinic_group = 2 then 1 else 0 end |
| EITHER_IND | This is indicates if the customer is a PDI or AZTech customer (this should cover every customer that we have in our database). This makes it easy to create filters on. | case when customer_customer.clinic_group in (1,2) then 1 else 0 end |
| ATTEMPT_STATUS_TIME | This is the date and time that we made our last communication attempt before the customer booked their appointment. The communication must have been made within the 60 days prior to their appointment. We decided to calculate it this way so we can give credit to callers who left a voicemail or text that the customer never actually responded to, but that still influenced them to make the appointment. | max(campaign_campaignstagecustomerresponse.attempt_status_time) where visit_visit.booked_at >= campaign_campaignstagecustomerresponse.attempt_status_time and visit_visit.booked_at <= campaign_campaignstagecustomerresponse.attempt_status_time + interval '60 days' |
| MSOPR_IND | This indicates whether or not the visit was due to the MSOP Retrospective campaign. MSOP Retrospective conversions are conversions of customers who have never received a MG with us in the past and who booked their MG after a non-MG appointment occurred. | campaign_campaignstagecustomerresponse.campaign_id = 6 and most_recent_previous_mg_appt.date_of_visit is null and most_recent_non_mg_appt.date_of_visit < mg_visit.booked_at |
| MSOPP_IND | This indicates whether or not the visit was due to the MSOP Prospective campaign. MSOP Prospective conversions are conversions of customers who have never received a MG with us in the past and who booked their MG after a non-MG appointment was booked, but before it occurred. | campaign_campaignstagecustomerresponse.campaign_id = 6 and most_recent_previous_mg_appt.date_of_visit is null and most_recent_non_mg_appt.date_of_visit >= mg_visit.booked_at and most_recent_non_mg_appt.booked_at <= mg_visit.date_of_visit |
| ANNUAL_IND | This indicates whether or not the visit was due to the Annual Reminder Campaign (this campaign includes the Manual Calling and Single Short Reminder campaigns). Annual Reminder conversions are conversions of customers who have had a MG in the past. | campaign_campaignstagecustomerresponse.campaign_id in (1,2,3) and most_recent_previous_mg_appt.date_of_visit < mg_visit.booked_at |
| WR_IND | This indicates whether or not the visit was due to any other WhiteRabbit campaign. This includes the Cancelation Handling Campaign. | campaign_campaignstagecustomerresponse.campaign_id = 5 |
| NATURAL_IND | This indicates whether or not the visit was due to a Natural Conversion. Natural Conversions are conversions of customers who have had a MG with us in the past and who were not contacted through a campaign before they booked their appointment. | campaign_campaignstagecustomerresponse.campaign_id is null and most_recent_previous_mg_appt.date_of_visit is not null |
| FIRST_TIME_IND | Description | This indicates whether or not the visit was due to a First Time Conversion. First Time Conversions are conversions of customers who have not had a MG with us in the past and who were not contacted through a campaign before they booked their appointment. | campaign_campaignstagecustomerresponse.campaign_id is null and most_recent_previous_mg_appt.date_of_visit is null |
| PREV_MG_DT | This is the date of the most recent MG appointment that the customer had with use before this MG appointment. | most_recent_previous_mg_appt.date_of_visit where most_recent_previous_mg_appt.date_of_visit < mg_visit.date_of_visit |
| RES_STAFF_USER_ID | This is the id from core_user and is the unique identifier for the employee who attempted to contact the customer  | campaign_campaignstagecustomerresponse.staff_user_id |
