;Get STEREO EUVI data from the local LMSAL repository
;Must have /archive1 mounted

function get_euvi_read, tstart, tend, a_sc=a_sc, b_sc=b_sc, wavelength=wavelength, $
	nodata=nodata, noindex=noindex, index=index, calibrate=calibrate, outsize=outsize, rebin1k=rebin1k, $
	rangesec=rangesec, filelist=infilelist, outfiles=filelist, skipmisscheck=skipmisscheck

skiplistfiles=0
if n_elements(infilelist) gt 0 then begin
	filelist=infilelist
	skiplistfiles=1
endif

if not keyword_set(a_sc) and not keyword_set(b_sc) then a_sc=1

if not keyword_set(rangesec) then rangesec=24.*3600.

;Make a list of all remote files in time range
ttstart=anytim((tstart),/vms)
if n_elements(tend) eq 1 then ttend=anytim((tend),/vms) else ttend=anytim(anytim(ttstart)+rangesec,/vms)

if keyword_set(rebin1k) then outsize=[1024,1024]

;/archive1/stereo

;Filelist is already input so skip the filtering etc.------------------------->
if skiplistfiles then goto,go_skiplistfiles

;Get EUVI file list
if keyword_set(a_sc) then $
	filelist=secchi_time2files(ttstart,ttend,/euvi,/ahead,/lz,dtype='img',pattern='*euA.fts',parent='/archive1/stereo')

if keyword_set(b_sc) then $
	filelist=secchi_time2files(ttstart,ttend,/euvi,/behind,/lz,dtype='img',pattern='*euB.fts',parent='/archive1/stereo')

;/archive1/stereo/lz/L0/a/img/euvi/20130421/20130421_234030_n4euA.fts

;!!!SECCHI CAT does not appear to exist anymore!!! WTF!!

;s=['wavelnth='+strtrim(wavelength,2),'beacon=0']
;if keyword_set(a_sc) then secchi_cat,ttstart,ttend,cat,filelist,search=s,/summary,/ahead,/euvi,count=count
;if keyword_set(b_sc) then secchi_cat,ttstart,ttend,cat,filelist,search=s,/summary,/behind,/euvi,count=count

;data=sccreadfits(filelist,index)

if keyword_set(noindex) then return,filelist

read_sdo,filelist,index,/nodata

;CHECK FOR MISSING FILES------------------------------------------------------>
if not keyword_set(skipmisscheck) then begin
   	if data_type(index) ne 8 then begin
		print,'NO FILES FOUND?'
		return,''
	endif
	wgood=where(index.nmissing eq 0)
	if wgood[0] eq -1 then begin
		print,'NO GOOD FILES FOUND!'
		print,'missing blocks: ',index.nmissing
		return,''
	endif
	filelist=filelist[wgood]
	index=index[wgood]
endif

;Filter for input wavelength
if n_elements(wavelength) eq 1 then begin
	;dum=sccreadfits(filelist,indfilt,/nodata)
	;mreadfits,filelist,indfilt,/nodata
	wgood=where(index.WAVELNTH eq wavelength)
	if wgood[0] ne -1 then begin
		filelist=filelist[wgood]
		index=index[wgood]
	endif
endif

if keyword_set(nodata) then return,filelist

;Read the files into map structures------------------------------------------->
go_skiplistfiles:

if keyword_set(calibrate) then $
	secchi_prep,filelist,index,data,/rotate_on,/rotatein,outs=outsize $;[1024,1024]
	else read_sdo,filelist,index,data
	
nmap=n_elements(index)
for i=0,nmap-1 do begin

	mindex2map,index[i],data[*,*,i],map,/nest

	if data_Type(maparr) ne 8 then maparr=map $
		else maparr=[maparr,map]

endfor
	
return,maparr

end
