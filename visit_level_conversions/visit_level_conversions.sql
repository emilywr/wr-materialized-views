--CREATE MATERIALIZED VIEW visit_level_conversions
--AS
with 
--this will pull all relevant customer responses
res as (
select
    res.customer_id
    ,res.attempt_status_time
    ,res.attempt_status
    ,res.campaign_id
    ,res.staff_user_id
    ,res.id
from campaign_campaignstagecustomerresponse res
where
    (res.attempt_Status in ('voice_mail','unreachable') or res.customer_response is not null)
    and 
    res.campaign_id in (1,2,3,5,6) --campaign 4 is the call-back 'campaign'. It isn't really a campaign and shouldn't be counted here. This was set up as a campaign to make the tab in the UI easier, but it's not really a campaign.
    and
    res.attempt_status_time > '2017-01-01'
)
,
--this will find all MG appointments 
vispastmg as (
select
    vispastmg.customer_id
    ,vispastmg.date_of_visit
    ,vispastmg.booked_at
from visit_visit vispastmg
where
    vispastmg.date_of_visit >= '2013-01-01'
    and 
    vispastmg.modality = 'MG'
    and 
    vispastmg.visit_status in ('BK', 'ED')
    and
    vispastmg.internal_procedure_code in ('MG141', 'MG104', 'MG114', 'MG139', 'MG158', 'MG113', 'MG140', 'HIST134', 'MG144', 'HIST129', 'MG136', 'HIST135', 'MG-156', 'MG156', 'MG104', 'MG150','77067','77067U','G0202','G0202U','MG138','MG137','MG132','MG107','MG111','MG112'
        ,'MG128','MG130','MG131','MG135','MG142','MG143','MG145','MG146','MG151','MG152','MG153','MG159')
)
,
--this will pull all screening MG appointments. This is our base.
vismg as (
select
    vismg.id
    ,vismg.customer_id
    ,vismg.date_of_visit
    ,vismg.booked_at
    ,pat.first_name
    ,pat.last_name
    ,pat.mrn
    ,pat.date_of_birth
    ,case when pat.clinic_group_id = 1 then 1 else 0 end as pdi_ind
    ,case when pat.clinic_group_id = 2 then 1 else 0 end as AZTECH_IND
    ,case when pat.clinic_group_id in (1,2) then 1 else 0 end as either_ind
from visit_visit vismg
    join customer_customer pat on vismg.customer_id = pat.id
where
    vismg.date_of_visit >= '2018-01-01'
    and 
    vismg.modality = 'MG'
    and 
    vismg.visit_status in ('BK', 'ED') 
	and
    upper(pat.first_name) not like '%TEST%' and upper(pat.last_name) not like '%TEST%' and upper(pat.first_name) not like '%ZZZ%' and upper(pat.last_name) not like '%ZZZ%' and upper(pat.first_name) not like '%VOID%' and upper(pat.last_name) not like '%VOID%'
    and
    vismg.internal_procedure_code in ('MG141', 'MG104', 'MG114', 'MG139', 'MG158', 'MG113', 'MG140', 'HIST134', 'MG144', 'HIST129', 'MG136', 'HIST135', 'MG-156', 'MG156', 'MG104', 'MG150','77067','77067U','G0202','G0202U','MG138','MG137','MG132','MG107','MG111','MG112'
        ,'MG128','MG130','MG131','MG135','MG142','MG143','MG145','MG146','MG151','MG152','MG153','MG159')
)
,
--this is where we start combinging our CTEs. 
combine_first as (
select
   res.attempt_status_time as res_attempt_status_time
    ,res.attempt_status as res_attempt_status
    ,res.campaign_id as res_campaign_id
    ,res.staff_user_id as res_staff_user_id
    ,res.id as res_id
    ,max(visnomg.date_of_visit) as visnomg_date_of_visit
    ,vismg.id as vismg_id
    ,vismg.customer_id as vismg_customer_id
    ,vismg.date_of_visit as vismg_date_of_visit
    ,vismg.booked_at as vismg_booked_at
    ,vismg.first_name as vismg_first_name
    ,vismg.last_name as vismg_last_name
    ,vismg.mrn as vismg_mrn
    ,vismg.pdi_ind as vismg_pdi_ind
    ,vismg.AZTECH_IND as vismg_AZTECH_IND
    ,vismg.either_ind as vismg_either_ind
    --we only want to keep the most recent contact that happened before the booking.
    ,row_number() over (partition by vismg.id order by res.attempt_status_time desc) as keep_ind
from vismg
    --if the appointment is booked on the day of a communication up to 60 days after the communication, then we say that the visit was influenced by that communication
    left join res on vismg.customer_id = res.customer_id
        and vismg.booked_at + interval '24 hours' >= (res.attempt_status_time) --the appt has to be booked after the MSOP attempt
        and vismg.booked_at + interval '24 hours' <= (res.attempt_status_time + interval '60 days') --if you don't book within 60 days of our contact, you are a natural/new convert
    --this is for the msop campaign - I want to see if the patient has had a non-MG appointment before this current appointment was booked.
    left join visit_visit visnomg on visnomg.customer_id = vismg.customer_id
        and date_trunc('day',visnomg.date_of_visit) < date_trunc('day',vismg.booked_at)
        and date_trunc('day',visnomg.date_of_visit) < date_trunc('day',vismg.date_of_visit)
        and visnomg.visit_status in ('BK','ED')
        and visnomg.modality != 'MG'
where
    vismg.date_of_visit >= '2018-08-01'
group by
    res.attempt_status_time,res.attempt_status,res.campaign_id,res.staff_user_id,res.id
    ,vismg.id,vismg.customer_id,vismg.date_of_visit,vismg.booked_at,vismg.first_name
    ,vismg.last_name,vismg.mrn,vismg.pdi_ind,vismg.AZTECH_IND,vismg.either_ind
)
,
--continue combining our CTEs.
final_combine as (
select
   combine_first.res_attempt_status_time
    ,combine_first.res_attempt_status
    ,combine_first.res_campaign_id
    ,combine_first.res_staff_user_id
    ,combine_first.res_id
    ,combine_first.visnomg_date_of_visit
    ,combine_first.vismg_id
    ,combine_first.vismg_customer_id
    ,combine_first.vismg_date_of_visit
    ,combine_first.vismg_booked_at
    ,combine_first.vismg_first_name
    ,combine_first.vismg_last_name
    ,combine_first.vismg_mrn
    ,combine_first.vismg_pdi_ind
    ,combine_first.vismg_AZTECH_IND
    ,combine_first.vismg_either_ind
    ,vispro.date_of_visit as vispro_date_of_visit
    ,max(vispastmg.date_of_visit) as vispastmg_prev_mg_dt
from combine_first
    --this is to differentiate msop prosspective from retrospective. If the current appointment was booked after a non-mg appointment was booked, but before the non-MG appointment occurred, then it's msop prospective. 
    left join visit_visit vispro on vispro.customer_id = combine_first.vismg_customer_id
        and date_trunc('day',vispro.booked_at) <= date_trunc('day',combine_first.vismg_booked_at)
        and date_trunc('day',vispro.date_of_visit) >= date_trunc('day',combine_first.vismg_booked_at)
        and vispro.visit_status in ('BK','ED')
        and vispro.modality != 'MG'
    --this is to check if a patient had a mg in the past
    left join visit_visit vispastmg on vispastmg.customer_id = combine_first.vismg_customer_id
        and date_trunc('day',vispastmg.date_of_visit) < date_trunc('day',combine_first.vismg_date_of_visit)
where
    combine_first.keep_ind = 1
group by 
    combine_first.res_attempt_status_time,combine_first.res_attempt_status,combine_first.res_campaign_id,combine_first.res_staff_user_id
    ,combine_first.res_id,combine_first.visnomg_date_of_visit,combine_first.vismg_id,combine_first.vismg_customer_id
    ,combine_first.vismg_date_of_visit,combine_first.vismg_booked_at,combine_first.vismg_first_name,combine_first.vismg_last_name
    ,combine_first.vismg_mrn,combine_first.vismg_pdi_ind,combine_first.vismg_AZTECH_IND,combine_first.vismg_either_ind
    ,vispro.date_of_visit
)
--make final indicators and calculations
select distinct
    final_combine.res_id AS ID
    ,final_combine.vismg_id as visit_id
    ,final_combine.vismg_customer_id as customer_id
    ,final_combine.vismg_first_name as first_name
    ,final_combine.vismg_last_name as last_name
    ,final_combine.vismg_date_of_visit as date_of_visit
    ,final_combine.vismg_booked_at as booked_at
    ,final_combine.res_campaign_id as campaign_id
    ,final_combine.vismg_mrn as mrn
    ,final_combine.vismg_pdi_ind as pdi_ind
    ,final_combine.vismg_AZTECH_IND as AZTECH_IND
    ,final_combine.vismg_either_ind as either_ind
    ,final_combine.res_attempt_status_time as attempt_status_time
    ,(case when res_campaign_id = 6  and vispro_date_of_visit is null and visnomg_date_of_visit is not null then 1.0 else 0 end) as msopr_ind --patients who had a MG appointment booked after a non-MG appt, but before the MG appt
        --MSOP prosepective will include patients who are scheduled for non-MG in the future
        --who we call and convert. The can also include patients who come in for a non-MG 
        --and who we convert at the front desk (per Sidd 2/6/2019)
    ,(case when res_campaign_id = 6 and vispro_date_of_visit is not null /*MSOP*/ then 1.0 else 0 end) as msopp_ind --patients who had an MG appointment booked after a non-MG appt occured
    ,(case when res_campaign_id in (1,2,3) /*Annual Reminder Campaign*/ then 1.0 else 0 end) as annual_ind -- per Rishi on 2/11/2019, the texting campaign (id 2 was a short-lived texting campaign that was an annual reminder campaign)
    ,(case when res_campaign_id = 5 /*Any campaign other than msop and annual reminder*/ then 1.0 else 0 end) as wr_ind 
    ,(case when res_campaign_id is null and vispastmg_prev_mg_dt is not null and res_attempt_status_time is null then 1.0 else 0 end) as natural_ind 
    ,case when (case when res_campaign_id = 6 and vispro_date_of_visit is not null /*MSOP*/ then 1.0 else 0 end) = 0
        and 
        (case when res_campaign_id = 6 and vispro_date_of_visit is null and visnomg_date_of_visit is not null then 1.0 else 0 end) = 0
        and 
        (case when res_campaign_id in (1,2,3) /*Annual Reminder Campaign*/ then 1.0 else 0 end) = 0
        and 
        (case when res_campaign_id = 5 /*Any campaign other than msop and annual reminder*/ then 1.0 else 0 end) = 0 
        and 
        (case when res_campaign_id is null and vispastmg_prev_mg_dt is not null and res_attempt_status_time is null then 1.0 else 0 end) = 0
        then 1 else 0 end 
        as first_time_ind
    ,final_combine.vispastmg_prev_mg_dt as prev_mg_dt
    ,res_staff_user_id
from final_combine
--WITH DATA;
												   
--REFRESH MATERIALIZED VIEW CONCURRENTLY visit_level_conversions;
												   
--DROP MATERIALIZED VIEW visit_level_conversions;
