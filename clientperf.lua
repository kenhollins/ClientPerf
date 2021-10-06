--[[ clientperf.lua
config:
add server svr_192.168.99.201 192.168.99.201
add service clientperf_svc1 svr_192.168.99.201 USER_TCP 80 -gslb NONE -maxClient 0 -maxReq 0 -cip DISABLED -usip NO -useproxyport YES -sp OFF -cltTimeout 180 -svrTimeout 360 -CKA NO -TCPB NO -CMP NO
add lb vserver clientperf_vip USER_TCP -persistenceType NONE -lbMethod ROUNDROBIN -cltTimeout 180
bind lb vserver clientperf_vip clientperf_svc1
import extension http://192.168.99.201/extensions/clientperf.lua CLIENTPERF_CODE -overwrite
add user protocol CLIENTPERF_TCP -transport TCP -extension clientperf_code
add user vserver clientperf_usrvip CLIENTPERF_TCP 192.168.99.221 80 -defaultLB clientperf_vip
connection error: 13.0_52.11\usr.src\sys\netscaler\ns_debug_common.h: #define NSBE_EXTENSION_CALL_ERROR		0XA126	/* 9889 */

to update code on NS:
rm user vserver clientperf_usrvip
rm user protocol CLIENTPERF_TCP
import extension http://192.168.1.200/extensions/clientperf.lua CLIENTPERF_CODE -overwrite
add user protocol CLIENTPERF_TCP -transport TCP -extension clientperf_code
add user vserver clientperf_usrvip CLIENTPERF_TCP 192.168.1.212 80 -defaultLB clientperf_vip

[versions]
[version: 1.0-0.2]
date: 04/06/2020
authors:
project manager: Ken Hollins
features: Medardus Clont
1. changed the code so the body length is figured out dynamically
2. process cut payload

[version: 1.0-0.1]
date: 04/24/2020
authors:
project manager: Ken Hollins
features: Medardus Clont
1. create main page
2. client features
2.1 client RTT test
2.2 client upload test
2.3 client side download test

[version: n.n-n.n]
date: 0n/0n/n0n0
authors:
project manager:
features:
1. blah
2. real feature, full

[backups]
1.0-0.0_clientperf.lua, CRTT feature working
--]]

--[[
    variable definition
--]]
local data = nil
local htmlPayload = nil
local verb = nil
local verbLine = nil
local test = nil
local crlfCharacter = "\n" -- GET / HTTP/1.1^M Host: 192.168.99.221^M Content-Length: 2^M ^M 
local spaceCharacter = " " -- GET / HTTP/1.1
-- client requsts to process
local CLIENTREQUESTS = {ROOT = 0, CRTT = 1, CUT = 2, CDT = 3, UPDATE = 4, FAVICONICO = 71, ERROR = 98, NONE = 99} -- add new requests before NONE and only increment by one and don't change the previous order
local clientRequest = CLIENTREQUESTS.ROOT
-- HMTL responses to return to client
local responseHeadersToDate = "HTTP/1.1 200 OK\r\nCache-Control: private\r\nServer: NetScaler\r\nDate: "
local responseHeadersCSToContentLength = " charset=utf-8\r\nContent-Length: "
local responseHeadersTypeJSON = "\r\nContent-Type: application/json;" .. responseHeadersCSToContentLength
local responseHeadersTypeHTML = "\r\nContent-Type: text/html;" .. responseHeadersCSToContentLength
local rootResponseBody = [[<html>
<head>
	<style>
		*{
		  box-sizing: border-box;
		}

		.header {
		  border: 1px solid red;
		  padding: 15px;
		}

		.row::after {
		  content: "";
		  clear: both;
		  display: table;
		}

		[class*="col-"] {
		  float: left;
		  padding: 15px;
		  border: 1px solid blue;
		}

		.col-1 {width: 8.33%;}
		.col-2 {width: 16.66%;}
		.col-3 {width: 25%;}
		.col-4 {width: 33.33%;}
		.col-5 {width: 41.66%;}
		.col-6 {width: 50%;}
		.col-7 {width: 58.33%;}
		.col-8 {width: 66.66%;}
		.col-9 {width: 75%;}
		.col-10 {width: 83.33%;}
		.col-11 {width: 91.66%;}
		.col-12 {width: 100%;}

		/*
		body {
			width: 900px;
			
			font-family: Verdana;
				
		}
		*/

		/* Style the header */
		header {
		  background-color: #666;
		  padding: 30px;
		  text-align: center;
		  font-size: 25px;
		  color: white;
		}

		article {
		  /* float: left; */
		  padding: 10px;
		  /* width: 25%; */
		  text-align: center;
		  background-color: #f1f1f1;
		  height: 60px; /* only for demonstration, should be removed */
		}

		button {
		  border: 2px solid powerblue;
		  padding: 10px;
		}
		nav {
		  border: 2px solid powderblue;
		  padding: 10px;
		}
		p {
		  border: 2px solid powderblue;
		  margin: 0px;
		  border: 0px;
		  padding: 10px;
		}
		a {
		  border: 2px solid blue;
		  padding: 10px;
		}
     </style>
	 
	<title>Client Performance</title>
	<script language="javascript">
	// test history per session
	// 1. since this is a browser session we store the test results in the browser's memory and once the browser is closed the results are lost
	// 2. format: object that holds a test request and a test response
	var objResponse = null;
	var objData = null;
	var requestURL = document.location.protocol+"/"+document.location.hostname+"/";
	var testStartTime = null;
	var testEndTime = null;
	let lastResponseTime = 0;
	
	// download vars
	// var downLoadTot = 0;
	// var downLoadRun = 0;
	var gCallsToMake = 0;
		
	const clientID = '_' + Math.random().toString(36).substr(2, 10); 
	
	function makeRequest(method, perfTest, processingFunction)
	{
		
		testStartTime = Date.now();
		if( perfTest == "CDT/" ){
			if( gCallsToMake <= 2 )
			objResponse.value += "makerequest: " + requestURL + perfTest + "\n";
		} else 
			objResponse.value += "makerequest: " + requestURL + perfTest + "\n";
				
		var requestXHR = new XMLHttpRequest();
		requestXHR.onreadystatechange = function()
		{
			if (this.readyState == 4)// && this.status == 200)
			{
				testEndTime = Date.now();
				if(method == "GET" && perfTest == "CRTT/" ){
					document.getElementById("ack_rtt_chk").innerHTML = "Duration " + (testEndTime-testStartTime) + " ms";
					processingFunction(this);
				}
				// if(method == "POST" && perfTest == "CUT/" ) {
				//	var obj2 = document.getElementById("txtSize");
				// todo calculate throughput since duration and 
				//	var mdata = "Size of upload: " + obj2.value + " and duration: " + testEndTime-testStartTime + " ms" ;
				// window.alert( mdata  );
				// }
				if(method == "POST" && perfTest == "CDT/" ){
					// call a processFunction !!!!
					var obj3 = document.getElementById( "downloadSize");
					// requestXHR.setRequestHeader("Download-Size", obj3.value );
					
					// window.alert( "In CDT" );
					
					gCallsToMake--;
					if (gCallsToMake >= 1 ) {
						
						downloadDataOfSize(true);
						
						//window.alert( obj3.value );
					}
				}
			}
		}
		
			
		requestXHR.open(method, perfTest, true);// method: 'GET', document.location: http://192.168.99.201/headertest.aspx
				
		if(objData.value.length > 0)
		{
			
			requestXHR.setRequestHeader( 'CLIENTID' , clientID );	
			requestXHR.setRequestHeader("Content-Type", "application/json");
			requestXHR.send("{\"data\":\"" + objData.value + "\"}");
			
			// window.alert( "length > 0" );
		} else
		{
			var obj3 = document.getElementById( "downloadSize");
			
			// window.alert("Download size: " + obj3.value);
			// window.alert("lastResponseTime: " + lastResponseTime );
			
			requestXHR.setRequestHeader("Download-Size", obj3.value );
			// requestXHR.setRequestHeader("Content-Type", "text/plain");
			
			requestXHR.setRequestHeader( 'CLIENTID' , clientID );
			if( lastResponseTime != 0 ) {
				let today = new Date();
				let date = today.getFullYear()+'-'+(today.getMonth()+1)+'-'+today.getDate();
				let time = today.getHours() + ":" + today.getMinutes() + ":" + today.getSeconds();
				const dateTime = date+ ' ' + time;
				
				requestXHR.setRequestHeader( 'CLIENTTime' , dateTime );
				requestXHR.setRequestHeader( 'CLIENTRTT' , lastResponseTime );
			}
			
			requestXHR.send(null);
			// window.alert("here");
			
		}
	}
	
	function processResponse(requestXHR)
	{
		testEndTime = Date.now();
		//var reqHeaders = requestXHR.getAllResponseHeaders();
		var responseText = requestXHR.responseText;
		lastResponseTime = (testEndTime-testStartTime);
		
		objResponse.value += "Test Start Time:" + testStartTime + " \nResponse:" + responseText + "\nTest End Time:" + testEndTime + "\nDuration:" + (testEndTime-testStartTime) + "\n";
				
	}
	
	function setObjs()
	{
		objResponse = document.getElementById("txtResponses");
		objData = document.getElementById("txtData");
		objResponse.value = "Objects set\n";
	}
	
	function generateData(size)
	{
		// var data = "abcdefghijklmnopqrstuvw"
		var data = "abcdefghijklmnopqrstuvwabcdefghijklmnopqrstuvwabcdefghijklmnopqrstuvwabcdefghijklmnopqrstuvwabcdefghijklmnopqrstuvwabcdefghijklmnopqrstuvw"

		objData.value = "";
		var index = 0;
		
		if(null != size && size > 0)
		{
			var divSize = parseInt(size/data.length);
			for(; index < divSize; index++)
			{
				objData.value += data;
			}
			
			objData.value += data.substring(0, size%data.length);
		}
		else
		{
			objData.value += data;
		}
	}
	
	function uploadDataOfSize()
	{
		var obj2 = document.getElementById("txtSize");
		generateData(obj2.value);
		makeRequest('POST', 'CUT/',processResponse);
	}
	function downloadDataOfSize(resume)
	{
		var i = 0;
		
		if (resume == false){
		
			var obj2 = document.getElementById("downloadSize");
			var mstr = "Size of download: " + obj2.value;
			// window.alert( mstr);
		
		
			gCallsToMake = obj2.value / 25;       // Dowload is 25KB chunks
		                                         // 100KB should run twice 1MB  should run 20 times
												 
			var callstr = "Calls to make: " + gCallsToMake;
			// window.alert( callstr);
		}
	
		makeRequest('POST', 'CDT/',processResponse);
		
	}
	
	function loadDoc() {
		var xhttp = new XMLHttpRequest();
		xhttp.onreadystatechange = function() {
		if (this.readyState == 4 && this.status == 200) {
			document.getElementById("ack_rtt_chk").innerHTML = this.responseText;
			}
		};
		xhttp.open("GET", "ajax_info.txt", true);
		xhttp.send();
	}
		
	function downloadDoc() {
		var xhttp = new XMLHttpRequest();
		xhttp.onreadystatechange = function() {
		if (this.readyState == 4 && this.status == 200) {
			document.getElementById("download_chk").innerHTML = "Download a file";
			}
		};
		xhttp.open("GET", "ajax_info.txt", true);
		xhttp.send();
	}
	</script>
	</head>
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	
	<body  onload="javascript:setObjs();">
	
	<header>
		<h2>ADC Client Perf</h2>
		<!----
		<nav class="backgroundradient">
			<ul>
				<li><a class="navlink" href="index.aspx">Home </a></li>
				<li><a class="navlink" href="index.aspx">Holder </a></li>
				<li><a class="navlink" href="index.aspx">Help </a></li>
			</ul>
		</nav>
		----->
		
	</header>
	
	<!--div class="header">
		<h1>ADC Client Perf</h1>
	</div-->

    <!----- Row 1 ------->
	<div class="row">
		<!----- <h2>Ken's Hack starts</h2> ------->
		<section>
			<div class="col-3">
				<article>
					
					<button title="Click to measure connection response." type="button" onclick="makeRequest('GET', 'CRTT/',processResponse)">Ack Return Time</button>
					<!--- ACK RTT: <p style="width=20px;" id="ack_rtt_chk">ACK.</p> ---> 
					<!--- textarea id="txtResponses" style="width:20; height:1"></textarea><br/ ---> 
					<!--- textarea id="ack_rtt_chk" value="0" style="width:50; height:10"> </textarea --->  
					<span id="ack_rtt_chk" value="0" > 
				</article>
			</div>
			
			<div class="col-3">
				<article>
					<button title="Set upload size and click" type="button" onclick="javascript:uploadDataOfSize();" >Upload Test</button>
					Upload size:
					<input id="txtSize" type="number" value="0" min="0" max="1000">
				</article>
			</div>
			<div class="col-3">
				<article>
					<button type="button" onclick="javascript:downloadDataOfSize(false);" >Download Test</button> 
					Download size:
					<input id="downloadSize" type="number" value="50" min="50" max="1000">
				</article>
			</div>
			<div class="col-3">
				<article>
					<button type="button" onclick="downloadDoc()">Response graph</button> 
				</article>
			</div>

		</section>
	</div>

	<!---- Row 2 --->
	<div class="row">
		<section>
			<div class="col-3">
				<article>
					<button id="poll_ack_ret" title="Click to measure connection response." type="button" >Poll ACK Return</button>
					<!--- ACK RTT: <p style="width=20px;" id="ack_rtt_chk">ACK.</p> ---> 
					<!--- textarea id="txtResponses" style="width:20; height:1"></textarea><br/ ---> 
					<!--- textarea id="ack_rtt_chk" value="0" style="width:50; height:10"> </textarea --->  
				</article>
			</div>
			
			<div class="col-3">
				<article>
					<button id="poll_upload_test" title="Set upload size and click" type="button" onclick="javascript:uploadDataOfSize();" >Poll Upload Test</button>
					Upload size:
					<input id="txtSize" type="number" value="0" min="0" max="1000">
				</article>
			</div>
			<div class="col-3">
				<article>
					<button type="button" onclick="downloadDoc()">Download Test</button> 
				</article>
			</div>
			<div class="col-3">
				<article>
					<button type="button" onclick="downloadDoc()">Response graph</button> 
				</article>
			</div>

		</section>
	</div>

	<br><br>
	

				
		<div class="row">	
			<!-- <a href="javascript:generateData(0);makeRequest('POST', 'CUT/',processResponse);">Upload Time</a><br/> <!--- this should be a post -->
	
		<!---	<input id="txtSize" type="text" value="0"><input type="button" onclick="javascript:uploadDataOfSize();" value="upload with size"/><br/>  this should be a post -->
		
		<!---
			<a href="javascript:makeRequest('GET', 'CDT/',processResponse);">Download Time</a><br/>
			<textarea id="txtResponses" style="width:300; height:150"></textarea><br/> 
			<textarea id="txtData" style="width:300; height:150"></textarea><br/>
		--->
		
			<div class="col-4">
				<a href="javascript:makeRequest('GET', 'CDT/',processResponse);">Download Time</a><br/>
			</div>
			<div class="col-4">
				
					<textarea id="txtResponses" style="width:300; height:150"></textarea><br/> 
				
			</div>
			<div class="col-4">
				
					<textarea id="txtData" style="width:300; height:150"></textarea><br/>
				
			</div>
		
		</div>
		
		<footer>
			<p>Footer</p>
		</footer>
		
		<script>
			/* */
			const pbutton = document.getElementById('poll_ack_ret');
			let halt=false;
			let timerID;
			
			function myPollAckHandler( index ){
				if(index-- > 0 && !halt){
					makeRequest('GET', 'CRTT/',processResponse);
					if(index > 0 ) {
						timerID = setTimeout(myPollAckHandler,  5000, index);       // todo add interval to HTML
					}
					else {
						// window.alert('Finish');
						pbutton.textContent = 'Poll ACK Return';
						lastResponseTime = 0;        // clear the GUI
						document.getElementById("ack_rtt_chk").innerHTML = 'eee';
					}
				}
			}
			
			pbutton.addEventListener('click', function(){
				if( pbutton.textContent == 'Poll ACK Return' ) {
					halt = false;
					myPollAckHandler( 3 );        // todo add a count to HTML
					pbutton.textContent = 'Stop ACK Return';
				} else {
					halt = true;
					pbutton.textContent = 'Poll ACK Return';
					lastResponseTime = 0;        // clear the GUI
					document.getElementById("ack_rtt_chk").innerHTML = '';
					clearTimeout(timeoutID);
				}
			});
	
		</script>
	</body>
</html>]]
local crttResponse = "{\"test\":\"CRTT\",\"status\":\"success\",\"error\":\"none\"}"
local cutResponse = "{\"test\":\"CUT\",\"status\":\"success\",\"error\":\"none\"}"
local cdtResponse = "{\"test\":\"CDT\",\"status\":\"success\",\"error\":\"none\"}"
local errorResponse = "{\"test\":\"NONE\",\"status\":\"faliure\",\"error\":\"Test not found!\"}"
local responseDate = nil
	
local function getHeaderForPage(page)
	local responseDate = os.date("%a, %d %b %Y %X")
	local responseHeaders = responseHeadersToDate ..  responseDate
	
	if((CLIENTREQUESTS.CRTT == page) or (CLIENTREQUESTS.CUT == page) or (CLIENTREQUESTS.CDT == page) or (CLIENTREQUESTS.ERROR == page)) then
		responseHeaders = responseHeaders .. responseHeadersTypeJSON
	else -- everything else is root
		responseHeaders = responseHeaders .. responseHeadersTypeHTML
	end
	
	return responseDate, responseHeaders
end

local function generateDownLoadData(size)
	local downLoadData = "{\"test\":"

	-- local downLoadPat = "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz"
	local downLoadPat = "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz"
	
	
	local patlen = #downLoadPat
	if size < 100 then
		size = 100
	end
	
	local remainder = size % patlen
	
	ns.logger:info("pclua generateDownLoadData using remainder : %d", remainder)
	
	local outBuff = downLoadPat
	
	-- ns.logger:info("pclua generateDownLoadData outBuff : %s", outBuff)
	
	while #outBuff < size - remainder do
		outBuff = outBuff .. downLoadPat
		-- ns.logger:info("pclua generateDownLoadData using NewSize : %d", #outBuff)
	end
	
	-- add the remainer
	outBuff = outBuff .. downLoadPat:sub( 1, remainder);
	
	ns.logger:info("pclua generateDownLoadData using NewSize : %d", #outBuff)
	-- ns.logger:info("pclua generateDownLoadData outBuff : %s", outBuff)

	-- add the closing quote and brace Json	
	-- local ending "\"}"
	-- outBuff = outBuff .. 
	
	ns.logger:info("pclua generateDownLoadData using NewSize : %d", #outBuff)
	
	return outBuff 
end

local function getBodyForPage(page)
	local responseBody = ""

	ns.logger:info("pclua getBodyForPage : %s", page)
	
	if(CLIENTREQUESTS.CRTT == page) then
		responseBody = crttResponse
	elseif(CLIENTREQUESTS.CUT == page) then
		responseBody = cutResponse
	elseif(CLIENTREQUESTS.CDT == page) then
		responseBody = generateDownLoadData(25000)
		--responseBody = cdtResponse
	elseif(CLIENTREQUESTS.ERROR == page) then
		responseBody = errorResponse
	else -- everything else is root
		responseBody = rootResponseBody
	end
	
	ns.logger:info("pclua getBodyForPage using : %s", responseBody)
	
	return responseBody:len(), responseBody
end


function client.on_data(ctxt, payload)
	data = payload.data
	clientRequest = CLIENTREQUESTS.ROOT
	local bodyLen = -1
	local body = nil
	local httpResponse = nil
	
	ns.logger:info("pclua initial response2: %s:%s", clientRequest, httpResponse)
	
	-- get the htmlPayload
	htmlPayload = data:sub(1) -- GET / HTTP/1.1^M Host: 192.168.99.221^M Content-Length: 2^M ^M
	-- split by crlf
	local offset = htmlPayload:find(crlfCharacter)
	ns.logger:info("pclua CRLF offset: %i", offset)
	-- print CRLF offset
	if (offset) then
		-- need offset check
		verbLine, htmlPayload = data:split(offset) -- GET / HTTP/1.1
		-- nil html payload as we don't need headers, but may contain post data ###
		htmlPayload = nil
		-- print verb line
		ns.logger:info("pclua verb line: %s", verbLine:sub(1))
		-- split verb line by space
		offset = verbLine:find(spaceCharacter)
		ns.logger:info("pclua First space: %i", offset)
		if (offset) then
			-- need offset check
			-- get verb
			verb, verbLine = verbLine:split(offset) -- GET
			--ns.logger:info("pclua Verb space: %s %s %s", verb:sub(1), type(verb), type(verb:sub(1)))
			-- convert to string
			verb = verb:sub(1)
			--ns.logger:info("pclua Verb is: %s", type(verb))
			-- remove space
			verb = verb:gsub("%s+", "")
			ns.logger:info("pclua Verb: %s", verb)
			-- split verb line by space again
			offset = verbLine:find(spaceCharacter)
			ns.logger:info("pclua Second space: %i", offset)
			if (offset) then
				-- need offset check
				-- get perf
				test, verbLine = verbLine:split(offset) -- /
				-- convert to string
				test = test:sub(1)
				-- remove space and period .
				test = test:gsub("%s+", ""):gsub("%.+", "")
				-- print test
				ns.logger:info("pclua test orig: %s", test)
				-- nil verbLine
				verbLine = nil
				-- remove / if test is longer than 1
				if (test:len() > 1) then
					-- remove slash
					test = test:gsub("%/+", ""):upper()
					-- print test
					ns.logger:info("pclua test upper: %s", test)
					clientRequest = CLIENTREQUESTS[test]
					ns.logger:info("pclua test id3: %s", clientRequest)
					
					if(not clientRequest) then
						clientRequest = CLIENTREQUESTS.ERROR
					end
				end
			end
		end
	end
	
	ns.logger:info("pclua processing: %s", clientRequest)
	
	-- now process the request
	-- get the body first because we get the length returned
	bodyLen, body = getBodyForPage(clientRequest)
	responseDate, httpResponse = getHeaderForPage(clientRequest)
	httpResponse = httpResponse .. bodyLen .. "\r\n\r\n" .. body
	
	-- we should check if we have all the data
	--verb, data = data:split(new_line_character_offset)
	
	ns.logger:info("Hello World payload!! %s", payload)
	-- ns.log:Apr 20 10:44:17 <local0.info> 192.168.99.31 04/20/2021:14:44:17 GMT  0-PPE-0 : default NSEXTENSION Message 500763 0 :  "Hello World4!! GET / HTTP/1.1^M Host: 192.168.99.221^M Content-Length: 2^M ^M "
	--ns.send(ctxt.output, "EOM", {data = data})
    ns.send(ctxt.client, "EOM", {data = httpResponse})
    return
end