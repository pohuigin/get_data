;Routine to stage data at LMSAL in my publin /sanhome/higgins/public_html/ directory
;For now, write compressed sav files...
;OUTDIR = directory within /sanhome/higgins/ to write files to. If directory does not exist, it will be created.
;		note: don't append slash to the end!

pro stage_data, tstart, tend, cadence=cadence, $
	getaia=getaia, gethmi=gethmi, getcont=getcont, wavelength=wavelength, $
	outdir=outdir

if n_elements(outdir) ne 1 then outdir='/'

rootdir='/sanhome/higgins/public_html/'

if n_elements(wavelength) ne 1 then wavelength=171

if keyword_set(getaia) then fname='aia'+strtrim(wavelength,2)+'_jsoc_sum_'
if keyword_set(gethmi) then fname='hmim45_jsoc_sum_'
if keyword_set(getcont) then fname='hmiic_jsoc_sum_'

dum=getjsoc_sdo_read(tstart, tend, cadence=cadence, outindex=index, $
	getaia=getaia, gethmi=gethmi, getcont=getcont, wavelength=wavelength, $
	info_struct=info_struct, /nodata, _extra=_extra)

help,info_struct,/str

;stop

if not file_exist(rootdir+outdir) then spawn,'mkdir '+rootdir+outdir,/sh

for i=0,n_elements(index)-1 do begin

;	map=getjsoc_sdo_read(tstart, getaia=getaia, gethmi=gethmi, getcont=getcont, wavelength=wavelength, $
;		filelist=(info_struct.FLISTLOC)[i], _extra=_extra)

read_sdo,(info_struct.FLISTLOC)[i],ind,dat
mindex2map,index[i],dat,map
	

;stop

	thisfile=rootdir+outdir+'/'+fname+time2file(map.date_obs,/sec)+'.fits'

	map2fits,map,thisfile

	spawn,'gzip -f '+thisfile

endfor











end