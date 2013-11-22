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

function getjsoc_synoptic_read, tstart, tend, wavelength=inwavelength, outpath=inoutpath, $
	info_struct=info_struct, nodata=nodata, filelist=infilelist, remfilelist=inremfilelist, _extra=_extra, outindex=indexarr, skipqualcheck=skipqualcheck

if keyword_set(inwavelength) then wavelength=string(inwavelength,form='(I04)') else wavelength='0304'

if keyword_set(nodata) then nodata=1 else nodata=0

if n_elements(tend) ne 1 then tend=tstart

if not keyword_set(inoutpath) then outpath='~/science/data/processed/synoptic_aia/' else outpath=inoutpath

;If a file list is supplied then skip the getting data
skipgetdata=0
if n_elements(infilelist) ge 0 and data_type(infilelist) eq 7 then begin
	skipgetdata=1
	filelist=infilelist
	goto,go_skipgetdata
endif
if n_elements(inremfilelist) ge 0 and data_type(inremfilelist) eq 7 then begin
	skip_search_data=1
	urls=inremfilelist
endif


;Make a list of all remote files in time range
ttstart=anytim((tstart),/vms)
ttend=anytim((tend),/vms)

;GET AIA----------------------------

;ssw_jsoc_time2data,ttstart,ttend,indexarr,urls,/urls_only,cadence=cadence,wave=wavelength,/jsoc2,/local_files
if not keyword_set(skip_search_data) then urls=ssw_time2filelist(ttstart,ttend,parent='http://jsoc.stanford.edu/data/aia/synoptic/',/hour,pattern='*'+wavelength+'.fits')

;Check for no data
if strtrim(urls[0],2) eq '0' then begin
	print,'1: NO DATA FOUND'
	return,''
endif

nurls=n_elements(urls)

date_obs=anytim(file2time(urls),/vms)

;Pull out the number dates of the files (yyyymmdd_hh_mm)
urlsfdates=strtrim(strmid(date_obs,0,4)+strmid(date_obs,5,2)+strmid(date_obs,8,2)+strmid(date_obs,11,2)+strmid(date_obs,14,2),2)

;Determine the ANYTIM format of the file times
urltim=anytim(date_obs)

;Get the local file names
break_url,urls,dum1,dum2,urlsloc
;urlsloc=strmid(urls,26,200)

;FILTER THE LIST OF URLS------------------------------------------------------>
;Check to see which ones exist
urlslocexist=file_exist(outpath+urlsloc)

;flag where quality flag is not "good data"
;if not keyword_set(skipqualcheck) then begin
;	wgood=where(indexarr.QUALLEV0 eq 0)
;   if wgood[0] eq -1 then begin
;      print,'3: NO GOOD FILES FOUND'
;      return,''
;   endif
;endif else wgood=findgen(nurls)

urlsquality=fltarr(nurls)
;urlsquality[wgood]=1

;filter out data tagged as "missing" (has missing date_obs?)
;if (where(urlsfdates ne 'MISSNG'))[0] eq -1 then begin
;	print,'4: ALL FILES MISSING'
;endif
;wbad=where(urlsfdates eq 'MISSNG')
;if wbad[0] ne -1 then urlsquality[wbad]=0

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

if keyword_set(nodata) then return,urls

if n_elements(nurls) ne 1 then nurls=n_elements(filelist)

for i=0,nurls-1 do begin

	if not skipgetdata then begin
		thisloc=outpath+urlsloc[i]
		thisrem=urls[i]

		sock_copy,thisrem,urlsloc[i],out_dir=outpath
	endif else begin
		thisrem=''
		thisloc=filelist
	endelse

	fexist=file_exist(thisloc)

	if fexist ne 1 then begin
		print,'FILE '+thisloc+' MISSING!'
		continue
	endif

	read_sdo,thisloc,index,data
	
;	aia_prep,index,data,_extra=_extra

	mindex2map,index,data,map,/nest

	coverage[i]=1
	flistrem[i]=thisrem
	flistloc[i]=thisloc
	date_obs[i]=map.time
	urlsquality[i]=index.QUALLEV0

;Extract spacecraft velocity along solar line of sight (units???)
	obs_vr[i]=index.obs_vr
	
;Extract distance of spacecraft to the Sun
	dsun_obs[i]=index.dsun_obs

	if n_elements(maparr) eq 0 then maparr=map else maparr=[maparr,map]

endfor

outmap=maparr
return,outmap

info_struct={date_obs:date_obs,coverage:coverage,flistrem:flistrem,flistloc:flistloc, $
	obs_vr:obs_vr, dsun_obs:dsun_obs, urltim:urltim, urlsfdates:urlsfdates, urlsquality:urlsquality}

if nodata then return,''

if data_type(maparr) ne 8 then begin
   print,'NO MAPS CONSTRUCTED!'
   return,''
endif

outmap=maparr

return,outmap

end
