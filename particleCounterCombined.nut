//Ver 130727-1633
/*
    Interface to Shinyei Model PPD42NS Particle Sensor
    Program by Christopher Nafis 130520
     and description http://www.howmuchsnow.com/WIFIparticle/
    Modified by Neil Hancock 130720
    Copyright (C) 2013
 131218: There are issues with the published concentration
 After running this for a couple of months, looking just at the
 particle count output, it needs some time metrics to make it useful.

 This code as is and while stable hasn't been tested for units or
 accuracy of any sort.
 
 http://www.seeedstudio.com/depot/grove-dust-sensor-p-1050.html
 http://www.sca-shinyei.com/pdf/PPD42NS.pdf

*/
local startcolor = 0;
local flash = 0;
local totalmillis = 0; 
local downmillis = 0;
const cPulseLenMax =200;
const cPulseShortInit =201;
local pulseshort =cPulseShortInit; //Shortest pulse, default high end
const cPulseLongInit = 0;
local pulselong =cPulseLongInit; //longest pulse, default low end
local particle1min_cnt =0; //pulses counted in 1ninute period
local pulse1hr_cnt =0;
local pulse1day_cnt=0;
local t = hardware.millis();
local old_t = t;
local ratioMin_per =0.0;
local maxconcentration = 1000;
local concentration =0.0;

/*   Rainbow colors for PWM RGB LED
*/
local R=[1,0,0.117647059,0.082352941,0.333333333,0.584313725,0.654901961,
0.898039216,0.898039216,0.898039216,0.898039216,0.898039216,0.917647059,
0.917647059,0.588235294,0.250980392,0.082352941,0.050980392,0.050980392,
0.066666667,0.050980392,0];
local G=[1,0,0.882352941,0.917647059,0.917647059,0.917647059,0.882352941,
0.678431373,0.498039216,0.341176471,0.098039216,0.098039216,0.082352941,
0.082352941,0.066666667,0.082352941,0.164705882,0.22745098,0.407843137,
0.588235294,0.949019608,1];
local B=[1,0,0.270588235,0.082352941,0.082352941,0.082352941,0.117647059,
0.098039216,0.098039216,0.098039216,0.098039216,0.341176471,0.584313725,
0.917647059,0.933333333,0.917647059,0.917647059,0.949019608,0.949019608,
0.933333333,0.949019608,1];
 
/*  define particle sensor pulse on Pin 2
*/
sensepin<-hardware.pin2;

/*
  Since there are not true interrupts, busy wait when we see a low pulse. 
  Otherwise we are not guaranteed to get back in time
*/
function PulseIn(){
    local level=sensepin.read();
    old_t = hardware.millis();

    if (level == 0) {
        while (level==0) {
            level=sensepin.read();    
        }
        t =hardware.millis();
        local pulselength = t-old_t;

        if (pulselength > 0)
        {    
            if ( pulselength <cPulseLenMax) { 
                downmillis = downmillis+pulselength;
                flash = 1;
                particle1min_cnt++;
                if (pulselength < pulseshort) pulseshort=pulselength;
                if (pulselength> pulselong ) pulselong=pulselength;
            } else pulseErr++;
        }
    }
}

/*
  Once a minute, update the color LED color and send the data to COSM
*/
function updateresults()
{
//    server.log("alive");
    ratioMin_per = downmillis/(60000*0.01);  // Integer percentage 0=>100
    concentration = 1.1*math.pow(ratioMin_per,3)-3.8*math.pow(ratioMin_per,2)+520*ratioMin_per+0.62; // using spec sheet curve
    if (0==particle1min_cnt)pulseshort=0;    
    server.log(format("Dvc1min: particles=%d, ratio=%5.3f%%, concentration=%7.1f, short=%3dms,long=%3dms,low=%3dms",
    particle1min_cnt,ratioMin_per,concentration,pulseshort,pulselong,downmillis));

    //agent.send("put", txData);  
    agent.send("putPsXv",{
      "Ratio": ratioMin_per
      ,"ParticleMin_cnt": particle1min_cnt
      ,"outputPtclSzMin": pulseshort
      ,"outputPtclSzMax": pulselong
      ,"outputconcentration": concentration
   });/* */
   
   agent.send("putPsTs",{
       "field5": concentration
      ,"field4": pulselong
      ,"field3": pulseshort
      ,"field2": particle1min_cnt
      ,"field1": ratioMin_per
    });/* */

    pulse1hr_cnt+=particle1min_cnt; 
    particle1min_cnt=0;
    pulseshort=cPulseShortInit;
    pulselong=cPulseLongInit;
    
    if (concentration > maxconcentration) {
        concentration = maxconcentration;
    }
    local c = concentration/maxconcentration*20+1;
    hardware.pin7.write(R[c]);
    hardware.pin8.write(G[c]);
    hardware.pin9.write(B[c]);

    downmillis = 0;
    imp.wakeup(60,updateresults);
}

/*
  When the sensor first starts up, run thru the rainbox colors to verify things are working
*/
function bootcolor(){
//    if (startcolor>21){
    if (startcolor>2){ //debug
        updateresults();
    }
    else {
        server.log("bootcolor");
        hardware.pin7.write(R[startcolor]);
        hardware.pin8.write(G[startcolor]);
        hardware.pin9.write(B[startcolor]);
                startcolor=startcolor+1;
        imp.wakeup(1.0,bootcolor);
    }
}

/*
   Configure output ports and display the IMP mac address on the IMP planner
   */
imp.configure("Shinyei PPD42NS(ver0.0ab)", [], []);//[outputRatioMin, outputParticleMin,outputPtclSzMin,outputPtclSzMax,outputconcentration]);
server.show(hardware.getimpeeid());
server.log(format("impMac %s impId %s SwVer %s",imp.getmacaddress(), hardware.getimpeeid(), imp.getsoftwareversion() ));
server.log(format("ssidMac %s Ram=%5.2fK",imp.getbssid() ,imp.getmemoryfree()/1000));
server.log(format("rssi %d dBm (above -67 good, down to -87 terrible)",imp.rssi()));


/*
   Configure the LED I/O pins for PWM, and set the default to white
*/
hardware.pin2.configure(DIGITAL_IN,PulseIn);
hardware.pin7.configure(PWM_OUT_STEPS, 1.0/1000, 0.0, 22);
hardware.pin8.configure(PWM_OUT_STEPS, 1.0/1000, 0.0, 22);
hardware.pin9.configure(PWM_OUT_STEPS, 1.0/1000, 0.0, 22);

hardware.pin7.write(R[1]);
hardware.pin8.write(G[1]);
hardware.pin9.write(B[1]);

bootcolor();

//EOF



**********agent
// EI Agent by Neil Hancock July 27, 2013 
// Agent to handle events from EI and push into Thingspeak.com and Xively.com
// Methods from marcboon July 13, 2013
//http://community.thingspeak.com/documentation/apps/thinghttp/
//http://lelylan.com/blog/thingspeak/
//http://forums.electricimp.com/discussion/1134/sharing-data-between-imps-using-xively-and-agents or 
//https://gist.github.com/marcboon/5634981

// Xively account credentials
const XivelyApiKey = "yourKey"
const XivelyFeedID = "yourFeed"
 
// Class for reading/writing a feed at xively.com (formerly cosm)
class XivelyFeed {
  static url = "https://api.xively.com/v2/feeds/"
  apiKey = null
  feedID = null

  constructor(apiKey, feedID) {
    this.apiKey = apiKey
    this.feedID = feedID
  }

  // Send data to feed, expects a table with channel:value pairs
  
  function push(data, callback) { //Xviley
    local datastreams = []
    foreach(channel, value in data) {
      //server.log("fPut: "+channel+"="+value)
      datastreams.push({ "id": channel, "current_value": value })
    }
    
    local body = { "version": "1.0.0", "datastreams": datastreams }
    local headers = { "X-ApiKey": apiKey, "Content-type": "application/json" }
    http.put(url + feedID + ".json", headers, http.jsonencode(body)).sendasync(callback)
  }
}//end XivelyFeed

// ThingSpeak account credentials
const TsApiWriteKey = "TsKey-----"
const TsChannelId = "TsId-----"

// Class for reading/writing a feed at thingspeak.com 
class TsFeed {
  static url = "http://api.thingspeak.com/update"
  wrApiKey = null
  feedID = null

  constructor(wrApiKey, feedID) {
    this.wrApiKey = wrApiKey
    this.feedID = feedID
  }

  // Send data to feed, expects a table with channel:value pairs
  //Min is http://api.thingspeak.com/update?key=3M1BQ5QP91DQWUPT%20&field1=62&field2=3&field3=5&field4=72&field5=65&%20status=REC005
  function push(data, callback) {//TsFeed
  // Example https://github.com/iobridge/ThingSpeak-Arduino-Examples/blob/master/Ethernet/Arduino_to_ThingSpeak.ino
    local datastreamTs = [] 
    foreach(channel, value in data) {
      server.log("TsPush: "+channel+"="+value)
      datastreamTs +=  "&"+channel + "=" + value 
    }

    local postHeaders = { //"POST /update HTTP/1.1",
        "Host": "api.thingspeak.com",  
        "Connection": "close", 
        "X-THINGSPEAKAPIKEY": wrApiKey,
        "Content-type": "application/x-www-form-urlencoded" }
    //server.log(format("%s",datastreamTs))
    http.post(url , postHeaders, datastreamTs).sendasync(callback)
  }
}//end TsFeed

// Post-update handler
function onUpdateXv(res) {
    if (200 != res.statuscode) server.log("AgtXvFail: " + res.statuscode )
}
function onUpdateTs(res) {
    if (200 != res.statuscode) server.log("AgtTsFail: " + res.statuscode )
}

// Handler for updates from device
device.on("putPsXv", function(data) {
  server.log("AgtPutXv: " + http.jsonencode(data))
  feedXv.push(data, onUpdateXv)
})
// Handler for updates from device
device.on("putPsTs", function(data) {
  server.log("AgtPutTs: " + http.jsonencode(data))
  feedTs.push(data, onUpdateTs)
})

// Create feed object
feedXv <- XivelyFeed(XivelyApiKey, XivelyFeedID)
feedTs <- TsFeed(TsApiWriteKey, TsChannelId)
//EOF
