clear
set more off
global path E:\sand storm\data\data\
cd "E:\sand storm\data\data\"




clear

use "residential solar electricity data.dta", clear

rename temp temp_old

gen pinal=(zipcode==85118 |zipcode==85119 | zipcode==85120 ///
|zipcode==85132 | zipcode==85140 | zipcode==85143 )
gen countyname="Pinal" if pinal==1
replace countyname="Maricopa" if pinal==0


rename DATE date
**********merge data
***ethnic group
merge m:1 vmatchbk using "household survey.dta"
drop if _merge==2
drop _merge

*climate
rename mo month
rename yr year
rename dy day

merge m:1 svc_zip year month day using "climate daily.dta"
drop if _merge==2
drop _merge

***wind direction
merge m:1 svc_zip year month day using "wind direction daily.dta"
drop if _merge==2
drop _merge


*percipitation
*merge m:1 year month day using "prcp record final.dta"
*drop if _merge==2
*drop _merge

*air pollution concentration
destring svc_zip, replace
merge m:1 svc_zip year month day using "air pollution daily.dta", force 
drop if _merge==2
drop _merge

*AQI new
merge m:1 countyname year month day using "AQI final new.dta" 
drop if _merge==2
drop _merge


*sand storm
merge m:1 year month day using "sand storm final.dta"
drop if _merge==2
drop _merge
replace stormevent=0 if stormevent==.

*thermal inversion
merge m:1 date using "therminv.dta"
rename therm_inv inversion
drop if _merge==2
drop _merge


***solar radiation
merge m:1 year month day using "solar irradiance.dta"
drop if _merge==2
drop _merge

***solar radiation new
merge m:1 year month day using "solar irradiance daily.dta"
drop if _merge==2
drop _merge

drop if consum<0
gen lnconsum=ln(consum)
gen lnprice=ln(price)
gen lnhousehold_income=ln(household_income)

***outage events
gen summer=(month>=5 & month<=10)

*gen solarinv=solar_treat*inversion

gen temp2=temp^2

gen rhmd2=rhmd^2

egen iddate=group(vmatchbk day month)

xtset vmatchbk date

*xtset iddate year

gen overallaqivalue_white=overallaqivalue*white

gen overallaqivalue_solar=overallaqivalue*solar_treat

*income group: https://www.pewsocialtrends.org/2016/05/11/americas-shrinking-middle-class-a-close-look-at-changes-within-metropolitan-areas/st_2016-05-12_middle-class-geo-03/

gen incomegroup="Lower income" if householdn!=. & household_income!=.
replace incomegroup="Middle income" if householdn==1.5 & household_income>(24.042+34)/2
replace incomegroup="Middle income" if householdn==3.5 & household_income>(41.641+48.083)/2
replace incomegroup="Middle income" if householdn==5 & household_income>53.759
replace incomegroup="Upper income" if householdn==1.5 & household_income>(72.126+102.001)/2 
replace incomegroup="Upper income" if householdn==3.5 & household_income>(124.925+144.251)/2  
replace incomegroup="Upper income" if householdn==5 & household_income>161.277 

gen ethnicgroup="Other" if ethnic!=""
replace ethnicgroup="White" if ethnic=="White/Caucasian"
replace ethnicgroup="Hispanic" if ethnic=="Hispanic"
*replace ethnicgroup="Black" if ethnic=="Black or African American"
replace ethnicgroup="Asian" if ethnic=="Asian"

gen cdd_new=max(temp*1.8+32-65, 0)
gen hdd_new=max(65-temp*1.8-32, 0)

*mkspline cdd_range 5 = cdd_new, pctile
*mkspline hdd_range 5 = hdd_new, pctile

*mkspline temp_range 6 = temp, pctile

*mkspline temp_old_range 6 = temp_old, pctile

egen alwayszero=max(consum), by(vmatchbk)

drop if alwayszero==0

gen season="winter"
replace season="summer" if month>=5 & month<=10
replace season="summer peak" if month==7 | month==8

**********************descriptive statistics
set more off
tabstat consum v_PM10_mean v_PM25_mean v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd price, statistics( N mean sd min max) save
mat StatTotal=r(StatTotal)'

putexcel set "residential descriptive statistics.csv",replace // remember to specify the full path
putexcel A1 = matrix(StatTotal,names)

tabstat he_dy, by(solar_treat) statistics( N mean sd min max) save
mat StatTotal=r(StatTotal)'
mat Stat1=r(Stat1)'
mat Stat2=r(Stat2)'

putexcel set "residential descriptive statistics.csv", modify // remember to specify the full path
putexcel A12 = matrix(StatTotal,names)
putexcel B13 = matrix(Stat1)
putexcel B14 = matrix(Stat2)

tabstat consum v_PM10_mean v_PM25_mean, by(incomegroup) statistics( N mean sd min max) save
mat StatTotal=r(StatTotal)'
mat Stat1=r(Stat1)'
mat Stat2=r(Stat2)'
mat Stat3=r(Stat3)'

putexcel set "residential descriptive statistics.csv", modify // remember to specify the full path
putexcel A15 = matrix(StatTotal,names)
putexcel B16 = matrix(Stat1)
putexcel B19 = matrix(Stat2)
putexcel B22 = matrix(Stat3)

set more off
tabstat consum v_PM10_mean v_PM25_mean, by(ethnicgroup) statistics( N mean sd min max) save
mat StatTotal=r(StatTotal)'
mat Stat1=r(Stat1)'
mat Stat2=r(Stat2)'
mat Stat3=r(Stat3)'
mat Stat4=r(Stat4)'

putexcel set "residential descriptive statistics.csv", modify // remember to specify the full path
putexcel A25 = matrix(StatTotal,names)
putexcel B26 = matrix(Stat1)
putexcel B29 = matrix(Stat2)
putexcel B32 = matrix(Stat3)
putexcel B35 = matrix(Stat4)

preserve

duplicates drop vmatchbk, force
set more off
tabstat SOLAR_KWAC SOLAR_KWDC, statistics( N mean sd min max) save
mat StatTotal=r(StatTotal)'
mat Stat1=r(Stat1)'
mat Stat2=r(Stat2)'
mat Stat3=r(Stat3)'
mat Stat4=r(Stat4)'

putexcel set "residential descriptive statistics.csv",modify // remember to specify the full path
putexcel A38 = matrix(StatTotal,names)

restore

**********************pollution check
set more off 
xtreg v_NO2_max1hour wind_cos v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday, fe vce(cluster vmatchbk)

set more off 
xtreg v_SO2_max1hour wind_cos v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday, fe vce(cluster vmatchbk)

set more off 
xtreg v_CO_max8hour wind_cos v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday, fe vce(cluster vmatchbk)

set more off 
xtreg v_Pb_mean wind_cos v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday, fe vce(cluster vmatchbk)

set more off 
xtreg v_PM10_mean wind_cos v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday, fe vce(cluster vmatchbk)

set more off 
xtreg v_PM25_mean wind_cos v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday, fe vce(cluster vmatchbk)

 
**********************main analysis
set more off
xtreg consum v_PM10_mean v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday, fe vce(cluster vmatchbk)
estimates store pm10_gls

set more off
xi: xtivreg2 consum (v_PM10_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday, fe cluster(vmatchbk) first savefirst
estimates store pm10_iv

set more off
xtreg consum v_PM25_mean v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday, fe vce(cluster vmatchbk)
estimates store pm25_gls

set more off
xi: xtivreg2 consum (v_PM25_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday, fe cluster(vmatchbk) first savefirst
estimates store pm25_iv

esttab pm10_gls _xtivreg2_v_PM10_mean pm10_iv pm25_gls _xtivreg2_v_PM25_mean pm25_iv ///
 using "residential results.csv", replace ///
 b(%6.3f) se(%6.3f) r2 star(* 0.10 ** 0.05  *** 0.01) ///
 keep(wind_cos v_PM10_mean v_PM25_mean v_Ozone_max8hour hdd_new cdd_new prcp wdsp rhmd lnprice _cons) ///
 order(wind_cos v_PM10_mean v_PM25_mean v_Ozone_max8hour hdd_new cdd_new prcp wdsp rhmd lnprice _cons) ///
 coeflabels(wind_cos "Wind cosine" v_PM10_mean "PM10 concentration" v_PM25_mean "PM2.5 concentration"  v_Ozone_max8hour "Ozone concentration" ///
 hdd_new "Heating degree days" cdd_new "Cooling degree days" prcp "Precipitation"  ///
 wdsp "Wind speed" rhmd "Relative humidity" lnprice "Daily electricity price (log)" _cons "Constant") ///
 mtitle("GLS" "IV" "IV" "GLS" "IV" "IV")
 
 
**********************main analysis by seasons
set more off
xi: xtivreg2 consum (v_PM10_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if season=="winter", fe cluster(vmatchbk) first savefirst
estimates store pm10_iv_winter

set more off
xi: xtivreg2 consum (v_PM25_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if season=="winter", fe cluster(vmatchbk) first savefirst
estimates store pm25_iv_winter

esttab _xtivreg2_v_PM10_mean pm10_iv_winter _xtivreg2_v_PM25_mean pm25_iv_winter ///
 using "residential results winter.csv", replace ///
 b(%6.3f) se(%6.3f) r2 star(* 0.10 ** 0.05  *** 0.01) ///
 keep(wind_cos v_PM10_mean v_PM25_mean v_Ozone_max8hour hdd_new cdd_new prcp wdsp rhmd lnprice _cons) ///
 order(wind_cos v_PM10_mean v_PM25_mean v_Ozone_max8hour hdd_new cdd_new prcp wdsp rhmd lnprice _cons) ///
 coeflabels(wind_cos "Wind cosine" v_PM10_mean "PM10 concentration" v_PM25_mean "PM2.5 concentration"  v_Ozone_max8hour "Ozone concentration" ///
 hdd_new "Heating degree days" cdd_new "Cooling degree days" prcp "Precipitation"  ///
 wdsp "Wind speed" rhmd "Relative humidity" lnprice "Daily electricity price (log)" _cons "Constant") ///
 mtitle("Winter" "Winter" "Winter" "Winter")

set more off
xi: xtivreg2 consum (v_PM10_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if season=="summer", fe cluster(vmatchbk) first savefirst
estimates store pm10_iv_summer

set more off
xi: xtivreg2 consum (v_PM25_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if season=="summer", fe cluster(vmatchbk) first savefirst
estimates store pm25_iv_summer

esttab _xtivreg2_v_PM10_mean pm10_iv_summer _xtivreg2_v_PM25_mean pm25_iv_summer ///
 using "residential results summer.csv", replace ///
 b(%6.3f) se(%6.3f) r2 star(* 0.10 ** 0.05  *** 0.01) ///
 keep(wind_cos v_PM10_mean v_PM25_mean v_Ozone_max8hour hdd_new cdd_new prcp wdsp rhmd lnprice _cons) ///
 order(wind_cos v_PM10_mean v_PM25_mean v_Ozone_max8hour hdd_new cdd_new prcp wdsp rhmd lnprice _cons) ///
 coeflabels(wind_cos "Wind cosine" v_PM10_mean "PM10 concentration" v_PM25_mean "PM2.5 concentration"  v_Ozone_max8hour "Ozone concentration" ///
 hdd_new "Heating degree days" cdd_new "Cooling degree days" prcp "Precipitation"  ///
 wdsp "Wind speed" rhmd "Relative humidity" lnprice "Daily electricity price (log)" _cons "Constant") ///
 mtitle("Summer" "Summer" "Summer" "Summer")

set more off
xi: xtivreg2 consum (v_PM10_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if season=="summer peak", fe cluster(vmatchbk) first savefirst
estimates store pm10_iv_summer_peak

set more off
xi: xtivreg2 consum (v_PM25_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if season=="summer peak", fe cluster(vmatchbk) first savefirst
estimates store pm25_iv_summer_peak

esttab _xtivreg2_v_PM10_mean pm10_iv_summer_peak _xtivreg2_v_PM25_mean pm25_iv_summer_peak ///
 using "residential results summer peak.csv", replace ///
 b(%6.3f) se(%6.3f) r2 star(* 0.10 ** 0.05  *** 0.01) ///
 keep(wind_cos v_PM10_mean v_PM25_mean v_Ozone_max8hour hdd_new cdd_new prcp wdsp rhmd lnprice _cons) ///
 order(wind_cos v_PM10_mean v_PM25_mean v_Ozone_max8hour hdd_new cdd_new prcp wdsp rhmd lnprice _cons) ///
 coeflabels(wind_cos "Wind cosine" v_PM10_mean "PM10 concentration" v_PM25_mean "PM2.5 concentration"  v_Ozone_max8hour "Ozone concentration" ///
 hdd_new "Heating degree days" cdd_new "Cooling degree days" prcp "Precipitation"  ///
 wdsp "Wind speed" rhmd "Relative humidity" lnprice "Daily electricity price (log)" _cons "Constant") ///
 mtitle("Summer peak" "Summer peak" "Summer peak" "Summer peak")



 
***by income

set more off
xi: xtivreg2 consum (v_PM10_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if incomegroup=="Lower income", fe cluster(vmatchbk) first
estimates store pm10_iv_low

set more off
xi: xtivreg2 consum (v_PM10_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if incomegroup=="Middle income", fe cluster(vmatchbk) first
estimates store pm10_iv_middle

set more off
xi: xtivreg2 consum (v_PM10_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if incomegroup=="Upper income", fe cluster(vmatchbk) first
estimates store pm10_iv_high

set more off
xi: xtivreg2 consum (v_PM25_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if incomegroup=="Lower income", fe cluster(vmatchbk) first
estimates store pm25_iv_low

set more off
xi: xtivreg2 consum (v_PM25_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if incomegroup=="Middle income", fe cluster(vmatchbk) first
estimates store pm25_iv_middle

set more off
xi: xtivreg2 consum (v_PM25_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if incomegroup=="Upper income", fe cluster(vmatchbk) first
estimates store pm25_iv_high


esttab pm10_iv_low pm10_iv_middle pm10_iv_high pm25_iv_low pm25_iv_middle pm25_iv_high ///
 using "residential income results.csv", replace ///
 b(%6.3f) se(%6.3f) r2 star(* 0.10 ** 0.05  *** 0.01) ///
 keep(v_PM10_mean v_PM25_mean v_Ozone_max8hour hdd_new cdd_new prcp wdsp rhmd lnprice _cons) ///
 order(v_PM10_mean v_PM25_mean v_Ozone_max8hour hdd_new cdd_new prcp wdsp rhmd lnprice _cons) ///
 coeflabels(v_PM10_mean "PM10 concentration" v_PM25_mean "PM2.5 concentration" v_Ozone_max8hour "Ozone concentration" ///
 hdd_new "Heating degree days" cdd_new "Cooling degree days" prcp "Precipitation"  ///
 wdsp "Wind speed" rhmd "Relative humidity" lnprice "Daily electricity price (log)" _cons "Constant") ///
 mtitle("Low income" "Middle income" "High income" "Low income" "Middle income" "High income")


***by ethnic group 
set more off
xi: xtivreg2 consum (v_PM10_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if ethnicgroup=="White", fe cluster(vmatchbk) first
estimates store pm10_iv_white

set more off
xi: xtivreg2 consum (v_PM10_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if ethnicgroup=="Hispanic", fe cluster(vmatchbk) first
estimates store pm10_iv_hispanic

set more off
xi: xtivreg2 consum (v_PM10_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if ethnicgroup=="Asian", fe cluster(vmatchbk) first
estimates store pm10_iv_asian

set more off
xi: xtivreg2 consum (v_PM10_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if ethnicgroup=="Other", fe cluster(vmatchbk) first
estimates store pm10_iv_other

set more off
xi: xtivreg2 consum (v_PM25_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if ethnicgroup=="White", fe cluster(vmatchbk) first
estimates store pm25_iv_white

set more off
xi: xtivreg2 consum (v_PM25_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if ethnicgroup=="Hispanic", fe cluster(vmatchbk) first
estimates store pm25_iv_hispanic

set more off
xi: xtivreg2 consum (v_PM25_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if ethnicgroup=="Asian", fe cluster(vmatchbk) first
estimates store pm25_iv_asian

set more off
xi: xtivreg2 consum (v_PM25_mean=wind_cos) v_Ozone_max8hour cdd_new hdd_new prcp wdsp rhmd lnprice i.year i.month weekend holiday if ethnicgroup=="Other", fe cluster(vmatchbk) first
estimates store pm25_iv_other

esttab pm10_iv_white pm10_iv_hispanic pm10_iv_asian pm10_iv_other ///
pm25_iv_white pm25_iv_hispanic pm25_iv_asian pm25_iv_other ///
 using "residential ethnic results.csv", replace ///
 b(%6.3f) se(%6.3f) r2 star(* 0.10 ** 0.05  *** 0.01) ///
 keep(v_PM10_mean v_PM25_mean v_Ozone_max8hour hdd_new cdd_new prcp wdsp rhmd lnprice _cons) ///
 order(v_PM10_mean v_PM25_mean v_Ozone_max8hour hdd_new cdd_new prcp wdsp rhmd lnprice _cons) ///
 coeflabels(v_PM10_mean "PM10 concentration" v_PM25_mean "PM2.5 concentration" v_Ozone_max8hour "Ozone concentration" ///
 hdd_new "Heating degree days" cdd_new "Cooling degree days" prcp "Precipitation"  ///
 wdsp "Wind speed" rhmd "Relative humidity" lnprice "Daily electricity price (log)" _cons "Constant") ///
 mtitle("White" "Hispanic" "Asian" "Other" "White" "Hispanic" "Asian" "Other")



 
 
***solar 
gen lnhe_dy=ln(he_dy)

set more off
xtreg he_dy v_PM10_mean cdd_new hdd_new prcp wdsp lnprice Surfacealbedo_a i.year i.month weekend holiday if solar_treat==1, fe vce(cluster vmatchbk)
estimates store pm10_gls_solar

set more off
xi: xtivreg2 he_dy (v_PM10_mean=wind_cos) cdd_new hdd_new prcp wdsp lnprice Surfacealbedo_a i.year i.month weekend holiday if solar_treat==1, fe cluster(vmatchbk) first savefirst
estimates store pm10_iv_solar

set more off
xtreg he_dy v_PM25_mean cdd_new hdd_new prcp wdsp lnprice Surfacealbedo_a i.year i.month weekend holiday if solar_treat==1, fe vce(cluster vmatchbk)
estimates store pm25_gls_solar

set more off
xi: xtivreg2 he_dy (v_PM25_mean=wind_cos) cdd_new hdd_new prcp wdsp lnprice Surfacealbedo_a i.year i.month weekend holiday if solar_treat==1, fe cluster(vmatchbk) first savefirst
estimates store pm25_iv_solar


esttab pm10_gls_solar _xtivreg2_v_PM10_mean pm10_iv_solar pm25_gls_solar _xtivreg2_v_PM25_mean pm25_iv_solar ///
 using "residential solar results.csv", replace ///
 b(%6.3f) se(%6.3f) r2 star(* 0.10 ** 0.05  *** 0.01) ///
 keep(wind_cos v_PM10_mean v_PM25_mean hdd_new cdd_new prcp wdsp lnprice Surfacealbedo_a _cons) ///
 order(wind_cos v_PM10_mean v_PM25_mean hdd_new cdd_new prcp wdsp lnprice Surfacealbedo_a _cons) ///
 coeflabels(wind_cos "Wind cosine" v_PM10_mean "PM10 concentration" v_PM25_mean "PM2.5 concentration" hdd_new "Heating degree days" ///
 cdd_new "Cooling degree days" prcp "Precipitation"  ///
 wdsp "Wind speed" lnprice "Daily electricity price (log)" Surfacealbedo_a "Solar irradiance" _cons "Constant") ///
 mtitle("GLS" "IV" "IV" "GLS" "IV" "IV")


***solar by seasons
set more off
xi: xtivreg2 he_dy (v_PM10_mean=wind_cos) cdd_new hdd_new prcp wdsp lnprice Surfacealbedo_a i.year i.month weekend holiday if solar_treat==1 & season=="winter", fe cluster(vmatchbk) first savefirst
estimates store pm10_iv_solar_winter

set more off
xi: xtivreg2 he_dy (v_PM25_mean=wind_cos) cdd_new hdd_new prcp wdsp lnprice Surfacealbedo_a i.year i.month weekend holiday if solar_treat==1 & season=="winter", fe cluster(vmatchbk) first savefirst
estimates store pm25_iv_solar_winter


esttab _xtivreg2_v_PM10_mean pm10_iv_solar_winter _xtivreg2_v_PM25_mean pm25_iv_solar_winter ///
 using "residential solar results winter.csv", replace ///
 b(%6.3f) se(%6.3f) r2 star(* 0.10 ** 0.05  *** 0.01) ///
 keep(wind_cos v_PM10_mean v_PM25_mean hdd_new cdd_new prcp wdsp lnprice Surfacealbedo_a _cons) ///
 order(wind_cos v_PM10_mean v_PM25_mean hdd_new cdd_new prcp wdsp lnprice Surfacealbedo_a _cons) ///
 coeflabels(wind_cos "Wind cosine" v_PM10_mean "PM10 concentration" v_PM25_mean "PM2.5 concentration" hdd_new "Heating degree days" ///
 cdd_new "Cooling degree days" prcp "Precipitation"  ///
 wdsp "Wind speed" lnprice "Daily electricity price (log)" Surfacealbedo_a "Solar irradiance" _cons "Constant") ///
 mtitle("Winter" "Winter" "Winter" "Winter")

 
set more off
xi: xtivreg2 he_dy (v_PM10_mean=wind_cos) cdd_new hdd_new prcp wdsp lnprice Surfacealbedo_a i.year i.month weekend holiday if solar_treat==1 & season=="summer", fe cluster(vmatchbk) first savefirst
estimates store pm10_iv_solar_summer

set more off
xi: xtivreg2 he_dy (v_PM25_mean=wind_cos) cdd_new hdd_new prcp wdsp lnprice Surfacealbedo_a i.year i.month weekend holiday if solar_treat==1 & season=="summer", fe cluster(vmatchbk) first savefirst
estimates store pm25_iv_solar_summer


esttab _xtivreg2_v_PM10_mean pm10_iv_solar_summer _xtivreg2_v_PM25_mean pm25_iv_solar_summer ///
 using "residential solar results summer.csv", replace ///
 b(%6.3f) se(%6.3f) r2 star(* 0.10 ** 0.05  *** 0.01) ///
 keep(wind_cos v_PM10_mean v_PM25_mean hdd_new cdd_new prcp wdsp lnprice Surfacealbedo_a _cons) ///
 order(wind_cos v_PM10_mean v_PM25_mean hdd_new cdd_new prcp wdsp lnprice Surfacealbedo_a _cons) ///
 coeflabels(wind_cos "Wind cosine" v_PM10_mean "PM10 concentration" v_PM25_mean "PM2.5 concentration" hdd_new "Heating degree days" ///
 cdd_new "Cooling degree days" prcp "Precipitation"  ///
 wdsp "Wind speed" lnprice "Daily electricity price (log)" Surfacealbedo_a "Solar irradiance" _cons "Constant") ///
 mtitle("Summer" "Summer" "Summer" "Summer")

 
set more off
xi: xtivreg2 he_dy (v_PM10_mean=wind_cos) cdd_new hdd_new prcp wdsp lnprice Surfacealbedo_a i.year i.month weekend holiday if solar_treat==1 & season=="summer peak", fe cluster(vmatchbk) first savefirst
estimates store pm10_iv_solar_summer_peak

set more off
xi: xtivreg2 he_dy (v_PM25_mean=wind_cos) cdd_new hdd_new prcp wdsp lnprice Surfacealbedo_a i.year i.month weekend holiday if solar_treat==1 & season=="summer peak", fe cluster(vmatchbk) first savefirst
estimates store pm25_iv_solar_summer_peak


esttab _xtivreg2_v_PM10_mean pm10_iv_solar_summer_peak _xtivreg2_v_PM25_mean pm25_iv_solar_summer_peak ///
 using "residential solar results summer peak.csv", replace ///
 b(%6.3f) se(%6.3f) r2 star(* 0.10 ** 0.05  *** 0.01) ///
 keep(wind_cos v_PM10_mean v_PM25_mean hdd_new cdd_new prcp wdsp lnprice Surfacealbedo_a _cons) ///
 order(wind_cos v_PM10_mean v_PM25_mean hdd_new cdd_new prcp wdsp lnprice Surfacealbedo_a _cons) ///
 coeflabels(wind_cos "Wind cosine" v_PM10_mean "PM10 concentration" v_PM25_mean "PM2.5 concentration" hdd_new "Heating degree days" ///
 cdd_new "Cooling degree days" prcp "Precipitation"  ///
 wdsp "Wind speed" lnprice "Daily electricity price (log)" Surfacealbedo_a "Solar irradiance" _cons "Constant") ///
 mtitle("Summer peak" "Summer peak" "Summer peak" "Summer peak")
