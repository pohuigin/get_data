;Read data from the local LMSAL SUMS mounts into SSWIDL MAP structures.
;Do cosine correction, rotate solar north up, zero off-limb pixels.
;
;VMS format times for TSTART, TEND
;CADENCE = JSOC cadence string
;REBIN = down sample the data to 1kx1k
;TIMEGRID = TODO!! find a file for each time grid cell. If a file is missing, fill with a blank array
;INFO_STRUCT = A structure with information about each of the magnetogram fits files
;NODATA = Set to just pull out INFO_STRUCT and skip the maps
;CALIBRATE = median filter, get-rid of non-finites, cosine correct, rotate, and zero off-limb pixels
;Magnetogram processing keywords:
;	nocos=nocos, nofilter=nofilter, nofinite=nofinite, noofflimb=noofflimb, norotate=norotate

function getjsoc_sdo_read, tstart, tend, cadence=cadence, timegrid=timegrid, $
	getaia=getaia, gethmi=gethmi, $
	info_struct=info_struct, nodata=nodata, calibratecalibrate, rebin=rebin, _extra=_extra
	

if keyword_set(nodata) then nodata=1 else nodata=0

if n_elements(tend) ne 1 then tend=tstart

;Make a list of all remote files in time range
ttstart=anytim((tstart),/vms)
ttend=anytim((tend),/vms)
ssw_jsoc_time2data,ttstart,ttend,indexarr,urls,/urls_only,cadence=cadence,ds='hmi.M_45s',/jsoc2,/local_files
nurls=n_elements(urls)

;Pull out the number dates of the files (yyyymmdd_hh_mm)
urlsfdates=strtrim(strmid(indexarr.date_obs,0,4)+strmid(indexarr.date_obs,5,2)+strmid(indexarr.date_obs,8,2)+strmid(indexarr.date_obs,11,2)+strmid(indexarr.date_obs,14,2),2)

;Determine the ANYTIM format of the file times
urltim=anytim(indexarr.date_obs)

;Get the local file names
urlsloc=strmid(urls,26,200)


;FILTER THE LIST OF URLS------------------------------------------------------>
;Check to see which ones exist
urlslocexist=file_exist(urlsloc)

;flag where quality flag is not "good data"
wgood=where(indexarr.quallev1 eq 0)
urlsquality=fltarr(nurls)
urlsquality[wgood]=1

;filter out data tagged as "missing" (has missing date_obs?)
wbad=where(urlsfdates eq 'MISSNG')
if wbad[0] ne -1 then urlsquality[wbad]=0

;INITIALISE ARRAYS------------------------------------------------------------>
;dates=TIMEGRID( ANYTIM(ttstart), ANYTIM(ttend), minutes=30, /VMS )
;datestims=anytim(dates)
;ndate=n_elements(dates)
coverage=fltarr(nurls)
flistloc=strarr(nurls) ;local files saved in SUMS archive
flistrem=strarr(nurls)
date_obs=strarr(nurls) ;list of observation times from fits

;Extracted observables
obs_vr=fltarr(nurls) ;velocity of the space craft in the radial direction from the Sun (+ is away from sun)
dsun_obs=fltarr(nurls) ;distance of spacecraft to the Sun

for i=0,nurls-1 do begin

	if urlslocexist[i] ne 1 or urlsquality[i] ne 1 then continue

;DO DATA STUFF----------------------------------------------------------------->
;Pull out the specific file name and header
	index=indexarr[i]
	thisurl=urls[i]
	thisurlloc=urlsloc[i]
	
;Note that there is data
	coverage[i]=1
	flistrem[i]=thisurl
	flistloc[i]=thisurlloc
	date_obs[i]=index.date_obs

;Extract spacecraft velocity along solar line of sight (units???)
	obs_vr[i]=index.obs_vr
	
;Extract distance of spacecraft to the Sun
	dsun_obs[i]=index.dsun_obs
;stop

if nodata then continue

;Extract the data
	read_sdo,thisurlloc,index_dum,data;,/useindex

;make data maps 
	mindex2map,index,data,map,/nest

;DO CALIBRATION--------------------------------------------------------------->
	if keyword_set(calibrate) then begin
		map=ar_processmag(map, _extra=_extra)
;			nocos=nocos, nofilter=nofilter, nofinite=nofinite, noofflimb=noofflimb, norotate=norotate

	endif

	if keyword_set(rebin) then begin	
;Reduce resolution to 1kx1k
		map=map_rebin(map,/rebin1k) ;reduce resolution using neighborhood averaging
	endif


	if n_elements(maparr) eq 0 then maparr=map $
		else maparr=[maparr,map]
	
endfor


info_struct={date_obs:date_obs,coverage:coverage,flistrem:flistrem,flistloc:flistloc, $
	obs_vr:obs_vr, dsun_obs:dsun_obs}

if nodata then return,''

outmap=maparr

return,outmap

end