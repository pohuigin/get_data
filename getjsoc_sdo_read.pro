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
	getaia=getaia, gethmi=gethmi, getcont=getcont, wavelength=inwavelength, $
	info_struct=info_struct, nodata=nodata, filelist=infilelist, calibrate=calibrate, rebin=rebin, _extra=_extra, outindex=indexarr, noaec=noaec

if keyword_set(inwavelength) then wavelength=inwavelength else wavelength='171'

if keyword_set(nodata) then nodata=1 else nodata=0

if n_elements(tend) ne 1 then tend=tstart

;If a file list is supplied then skip the gettign data
skipgetdata=0
if n_elements(infilelist) ge 0 and data_type(infilelist) eq 7 then begin
	skipgetdata=1
	filelist=infilelist
	goto,go_skipgetdata
endif

;Make a list of all remote files in time range
ttstart=anytim((tstart),/vms)
ttend=anytim((tend),/vms)

;GET HMI----------------------------
if keyword_set(gethmi) then $
	ssw_jsoc_time2data,ttstart,ttend,indexarr,urls,/urls_only,cadence=cadence,ds='hmi.M_45s',/jsoc2,/local_files


;GET Continuum----------------------------
if keyword_set(getcont) then $
	ssw_jsoc_time2data,ttstart,ttend,indexarr,urls,/urls_only,cadence=cadence,ds='hmi.Ic_45s',/jsoc2,/local_files


;GET AIA----------------------------
if keyword_set(getaia) then $
	ssw_jsoc_time2data,ttstart,ttend,indexarr,urls,/urls_only,cadence=cadence,wave=wavelength,/jsoc2,/local_files

;To filter out AEC auto exposure time scaling with AIA
if keyword_set(noaec) then begin
	wgood=where(indexarr.aectype le 1)
	if wgood[0] eq -1 then begin & print,'1: No data with NOAEC available in time range!' & return,'' & endif
	indexarr=indexarr[wgood]
	urls=urls[wgood]
endif

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
if keyword_set(gethmi) or keyword_set(getcont) then wgood=where(indexarr.quallev1 eq 0) $
	else wgood=where(indexarr.QUALLEV0 eq 0)
urlsquality=fltarr(nurls)

if wgood[0] eq -1 then begin
	print,'2: NO GOOD FILES FOUND'
	return,''
endif

urlsquality[wgood]=1

;filter out data tagged as "missing" (has missing date_obs?)
if (where(urlsfdates ne 'MISSNG'))[0] eq -1 then begin
	print,'3: ALL FILES MISSING'
endif
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

go_skipgetdata:

if n_elements(nurls) ne 1 then nurls=n_elements(filelist)

for i=0,nurls-1 do begin

	if not skipgetdata then begin
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
	endif

if nodata then continue

;Extract the data
if skipgetdata then read_sdo,filelist,index,data $
	else read_sdo,thisurlloc,index_dum,data;,/useindex

;make data maps 
	mindex2map,index,data,map

;DO CALIBRATION--------------------------------------------------------------->
	if keyword_set(calibrate) then begin
		if keyword_set(gethmi) then $
			map=ar_processmag(map, _extra=_extra)
;				nocos=nocos, nofilter=nofilter, nofinite=nofinite, noofflimb=noofflimb, norotate=norotate
		if keyword_set(getaia) then begin
			aia_prep,index,data,_extra=_extra
			mindex2map,index,data,map
		endif
		if keyword_set(getcont) then $
			map=ar_processmag(map, _extra=_extra, /nocos, /nofilter, /noofflimb)
	
	endif

	if keyword_set(rebin) then begin	
;Reduce resolution to 1kx1k
		map=map_rebin(map,/rebin1k) ;reduce resolution using neighborhood averaging
	endif


	if n_elements(maparr) eq 0 then maparr=map $
		else maparr=[maparr,map]
	
endfor

if skipgetdata then begin
	outmap=maparr
	return,outmap
endif

info_struct={date_obs:date_obs,coverage:coverage,flistrem:flistrem,flistloc:flistloc, $
	obs_vr:obs_vr, dsun_obs:dsun_obs}

if nodata then return,''

outmap=maparr

return,outmap

end