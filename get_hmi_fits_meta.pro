;20131028
;Make a list of HMI LOS mags for 2011-2013 for hourly SMART run, to be ingested in HEK and used for studies
;get the full path and local /SUMS filenames and indexes so data can be read directly from mount.

pro get_hmi_fits_meta

datapath='~/science/data/processed/smart2_hmi/fits_meta/'

tstart='10-apr-2010 00:30'
tend='1-jan-2014 00:30'

days=anytim(timegrid(tstart,tend,/day),/vms)
fdays=time2file(days)

times=anytim(timegrid(tstart,tend,/month),/vms)
fdates=time2file(times)
months=strmid(fdates,0,6)
nmonth=n_elements(months)

fmetalist=''

for i=0,nmonth-1 do begin

	spawn,'mkdir '+datapath+months[i],/sh
	
	
	;list the days for this month
	wmonth=where(strpos(fdays,months[i]) ne -1)
	thisdays=days[wmonth]
	ndays=n_elements(thisdays)
	
	;loop over each day
	
	for j=0,ndays-1 do begin

		;search each day individually and pull out the hourly hmi files
	
		thisday=thisdays[j]
		ttstart=anytim(thisday,/vms)
		ttend=anytim(anytim(thisday)+3600.*24.,/vms)

;print,months[i]
;print,thisdays[0],(reverse(thisdays))[0]
;print,ttstart,ttend
;stop
;continue

		indexarr=getjsoc_sdo_read( ttstart, ttend, cadence='60m',/gethmi,info=infoarr,/nodat)
		
		if data_type(indexarr) ne 8 then continue
		
		thismeta=datapath+months[i]+'/'+time2file(ttstart)+'.sav'
		
		save,indexarr,infoarr,file=thismeta
		
		fmetalist=[fmetalist,thismeta]
		
	endfor

endfor


fmetalist=fmetalist[1:*]

save,fmetalist,file=datapath+'hmi_fits_meta_file_list.sav'




stop

end