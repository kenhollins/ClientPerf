<html>
<head>
	
	<link rel="stylesheet" href="Styles/Layout.css" type="text/css" />
     
	 
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
	
	const clientID = '_' + Math.random().toString(36).substr(2, 10); //
	
	// window.alert( 'Client ID: ' + clientID );
	
	// Todo - Make sure we don't run more than one.
	
	function makeRequest(method, perfTest, processingFunction)
	{
		
		testStartTime = Date.now();
		objResponse.value += "makerequest: " + requestURL + perfTest + "\n";
				
		var requestXHR = new XMLHttpRequest();
		requestXHR.onreadystatechange = function()
		{
			if (this.readyState == 4)// && this.status == 200)
			{
				processingFunction(this);
				if(method == "GET" && perfTest == "CRTT/" )
					document.getElementById("ack_rtt_chk").innerHTML = "Duration " + (testEndTime-testStartTime) + " ms";
				// if(method == "POST" && perfTest == "CUT/" ) {
				//	var obj2 = document.getElementById("txtSize");
				// todo calculate throughput since duration and 
				//	var mdata = "Size of upload: " + obj2.value + " and duration: " + testEndTime-testStartTime + " ms" ;
				// window.alert( mdata  );
				// }
				
				
			}
		};
		requestXHR.open(method, perfTest, true);// method: 'GET', document.location: http://192.168.99.201/headertest.aspx
		if(objData.value.length > 0)
		{
			requestXHR.setRequestHeader("Content-Type", "application/json");
			requestXHR.send("{\"data\":\"" + objData.value + "\"}");
			
			// window.alert( "length > 0" );
		}
		else
		{
			// window.alert( "lastResponseTime: " + lastResponseTime);
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
			// window.alert( "length <= 0" );
		}
	}
	
	function processResponse(requestXHR)
	{
		testEndTime = Date.now();
		//var reqHeaders = requestXHR.getAllResponseHeaders();
		var responseText = requestXHR.responseText;
		lastResponseTime = (testEndTime-testStartTime);
		
		objResponse.value += "Test Start Time:" + testStartTime + " \nResponse:" + responseText + "\nTest End Time:" + testEndTime + "\nDuration:" + (lastResponseTime) + "\n";
		
		// const pbutton = document.getElementById('poll_ack_ret');		
		// window.alert('Resetting button text');
		// pbutton.textContent = 'Poll ACK Return';

				
	}
	
	function processUpdate(requestXHR)
	{
		testEndTime = Date.now();
		//var reqHeaders = requestXHR.getAllResponseHeaders();
		var responseText = requestXHR.responseText;
		
		// objResponse.value += "Test Start Time:" + testStartTime + " \nResponse:" + responseText + "\nTest End Time:" + testEndTime + "\nDuration:" + (testEndTime-testStartTime) + "\n";
		
		const pbutton = document.getElementById('poll_ack_ret');		
		if( pbutton.textContent == 'Stop ACK Return' ) {
			window.alert('adding client ID ');
			
			requestXHR.setRequestHeader( 'CLIENTID' , clientID );
			requestXHR.setRequestHeader( 'CLIENTRTT' , testEndTime-testStartTime );
			
			const newDate = new Date();
			
			const dateTime = "LastSync: " + newDate.today() + " @ " + newDate.timeNow();
			
			requestXHR.setRequestHeader( 'CLIENTTime' , dateTime );
			
			// pbutton.textContent = 'Stop ACK Return';
			
			// requestXHR.send(null);
		
			// window.alert('Resetting button text');
			// pbutton.textContent = 'Poll ACK Return';
		}
				
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
</html>