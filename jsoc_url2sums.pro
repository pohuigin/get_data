;convert a full JSOC URL to a local SUMS directory

function jsoc_url2sums,url

wsum=strpos(url,'SUM')

if wsum[0] eq -1 then return, url

outurl='/'+strmid(url,wsum,strlen(url)-1)

return,outurl

end