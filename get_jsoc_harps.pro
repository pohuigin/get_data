;Get NRT SHARPs from the JSOC from LMSAL
;At the moment it just gets cut-outs for the last SHARP time on record.

pro get_jsoc_harps, outfiles=outfiles, err=err, stagelocal=stagelocal, clearold=clearold, requestid=inrequestid ;, $
;  latest=latest, outbr=outbr, outnoaa=outnoaa, outcont=outcont, nodata=nodata 

err=0

localpath='/Users/higgins/science/projects/max_millennium/temp/'

if keyword_set(stagelocal) and keyword_set(clearold) then spawn,'rm /Users/higgins/science/projects/max_millennium/temp/*.fits',/sh

sock_list,'http://jsoc2.stanford.edu/cgi-bin/ajax/jsoc_info?op=series_struct&ds=hmi.sharp_cea_720s_nrt',list

wlastrec=(where(strpos(list,'LastRecord') ne -1))[0]
if wlastrec eq -1 then begin
   print,'Status 1: Keyword LastRecord not found in series info listing.'
   err=1
   return
endif

lastrecline=list[wlastrec]

print,'LASTRECLINE'
print,lastrecline

series_date=(str_sep(lastrecline,'"'))[3]

date=strmid((str_sep(series_date,'['))[2],0,23) 

print,'Getting HARPS for '+date

yyyy=strmid(date,0,4)
mo=strmid(date,5,2)
dd=strmid(date,8,2)
hh=strmid(date,11,2)
mi=strmid(date,14,2)
ss=strmid(date,17,2)

;Check for input RequestID (already staged data)
if n_elements(inrequestid) eq 1 then begin
   requestid=inrequestid
   goto,skipstagedata
endif

sock_list,'http://jsoc2.stanford.edu/cgi-bin/ajax/jsoc_fetch?op=exp_request&ds=hmi.sharp_cea_720s_nrt[]['+YYYY+'.'+mo+'.'+dd+'_'+hh+'%3A'+mi+'%3A'+ss+'_TAI]&process=no_op&method=url&format=txt&protocol=FITS,**NONE**&filenamefmt%3D{seriesname}.{recnum%3A%25lld}.{segment}',querylist

print,'QUERY LIST'
print,transpose(querylist)

wrequestid=(where(strpos(querylist,'requestid=') ne -1))[0]

if wrequestid eq -1 then begin
   print,'Status 2: Keyword requestid not found in query output listing.'
   err=2
   return
endif

requestidline=querylist[wrequestid]

requestid=(str_sep(requestidline,'='))[1]

;Wait for the data to be ready------------------------------------------------->

wwait=(where(strpos(querylist,'wait=') ne -1))[0]

if wrequestid eq -1 then begin
   print,'Status 3: Keyword wait not found in query output listing.'
   err=3
   return
endif

waitline=querylist[wwait]

waitnum=(str_sep(waitline,'='))[1]

wait,waitnum+5.0

;Get the data listing---------------------------------------------------------->

skipstagedata:

sock_list,'http://jsoc2.stanford.edu/cgi-bin/ajax/jsoc_fetch?op=exp_status&requestid='+requestid+'&format=txt',datalist

wdatadir=(where(strpos(datalist,'dir=') ne -1))[0]

if wdatadir eq -1 then begin
   print,'Status 4: Keyword dir= not found in query data listing.'
   err=4
   if n_elements(waitnum) ne 1 then waitnum=10.0

   i=0
   while i lt 3 do begin
      sock_list,'http://jsoc2.stanford.edu/cgi-bin/ajax/jsoc_fetch?op=exp_status&requestid='+requestid+'&format=txt',datalist
      i=i+1
      if (where(strpos(datalist,'dir=') ne -1))[0] ne -1 then break
      wait,waitnum+5.0
   endwhile
   wdatadir=(where(strpos(datalist,'dir=') ne -1))[0]
   if wdatadir eq -1 then return
   print,'Status 4 cancelled! Got data listing!...'
endif

datadirline=datalist[wdatadir]

datadir=(str_sep(datadirline,'='))[1]

;Pull out the file names needed------------------------------------------------>

contpos=strpos(datalist,'continuum.fits')
wcontline=(where(contpos ne -1))
magpos=strpos(datalist,'magnetogram.fits')
wmagline=(where(magpos ne -1))
brpos=strpos(datalist,'Br.fits')
wbrline=(where(brpos ne -1))

if wcontline[0] eq -1 then begin
   print,'Status 5: No Continuums found in query data listing.'
   err=5
   return
endif

if wmagline[0] eq -1 then begin
   print,'Status 6: No Magnetograms found in query data listing.'
   err=6
   return
endif

if wbrline[0] eq -1 then begin
   print,'Status 7: No Radial Magnetograms found in query data listing.'
   err=7
   return
endif

linelengths=strlen(datalist)
fpos=strpos(datalist,'hmi.sharp_cea_720s_nrt.')

nfc=n_elements(wcontline)
nfm=n_elements(wmagline)
nfb=n_elements(wbrline)

if nfc ne nfm or nfc ne nfb or nfb ne nfm then begin
   print,'Status 8: Numbers of file types are not equal.'
   err=8
   return
endif

nf=nfc

fcont=strarr(nf)
fmag=strarr(nf)
fbr=strarr(nf)

localcont=strarr(nf)
localmag=strarr(nf)
localbr=strarr(nf)

for i=0,nf-1 do begin

   fcont[i]=datadir+'/'+strmid(datalist[wcontline[i]],fpos[wcontline[i]],linelengths[wcontline[i]]-1)
   fmag[i]=datadir+'/'+strmid(datalist[wmagline[i]],fpos[wmagline[i]],linelengths[wmagline[i]]-1)
   fbr[i]=datadir+'/'+strmid(datalist[wbrline[i]],fpos[wbrline[i]],linelengths[wbrline[i]]-1)

   localcont[i]=localpath+'/'+strmid(datalist[wcontline[i]],fpos[wcontline[i]],linelengths[wcontline[i]]-1)
   localmag[i]=localpath+'/'+strmid(datalist[wmagline[i]],fpos[wmagline[i]],linelengths[wmagline[i]]-1)
   localbr[i]=localpath+'/'+strmid(datalist[wbrline[i]],fpos[wbrline[i]],linelengths[wbrline[i]]-1)

endfor

print,fcont
print,fmag
print,fbr

if keyword_set(stagelocal) then begin
   for i=0,nf-1 do begin 
      spawn,'cp '+fcont[i]+' '+localpath,/sh
      wait,0.5
      spawn,'cp '+fmag[i]+' '+localpath,/sh
      wait,0.5
      spawn,'cp '+fbr[i]+' '+localpath,/sh
      wait,0.5
      
   endfor

   outfiles=[localcont,localmag,localbr]

endif

print,'Local files exist?: '+strjoin(string(file_exist(outfiles),form='(I1)'),' ')

print,'Finished!'

end
