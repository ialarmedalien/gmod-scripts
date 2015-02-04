/*!
 * IP Address geocoding API for Google Maps
 * original by Abhinay Rathore, http://lab.abhinayrathore.com/ipmapper/
 * Last Updated: June 13, 2012
 * customised by girlwithglasses, amelia.ireland@gmail.com
 */

var IPMapper = {
	map: null,
	mapTypeId: google.maps.MapTypeId.ROADMAP,
	latlngbound: null,
	infowindow: null,
	baseUrl: "http://freegeoip.net/json/",
	opt: null,
	initializeMap: function(mapId){
	IPMapper.latlngbound = new google.maps.LatLngBounds();
	var latlng = new google.maps.LatLng(0, 0);
	//set Map options
	var mapOptions = {
		zoom: 1,
		center: latlng,
		mapTypeId: IPMapper.mapTypeId
	};
	//init Map
	IPMapper.map = new google.maps.Map(document.getElementById(mapId), mapOptions);
	//init info window
	IPMapper.infowindow = new google.maps.InfoWindow();
	//info window close event
	google.maps.event.addListener(IPMapper.infowindow, 'closeclick', function() {
		//IPMapper.map.fitBounds(IPMapper.latlngbound);
		//IPMapper.map.panToBounds(IPMapper.latlngbound);
	    });
    },
    // adding points to a map using data we gathered on a previous occasion
    addMapData: function(jsonArr, options){
		if (typeof options == 'undefined')
			//set options
		{	IPMapper.opt = {'latitude':'1','longitude':'1','city':'1','region':'1','country':'1'};
		}
		else
		{	IPMapper.opt = options;
		}
		var i;
		for (i=0;i < jsonArr.length;i++) {
			IPMapper.addMarker(jsonArr[i]);
		//	alert('Check it out! I just added ' + jsonArr[i]['city']);
		}
    },
	// for input in the form { dbhost: xxx, url: xxx, title: xxx, about: xxx }
	addDbArray: function(dbArr, options){
		if (typeof options == 'undefined')
		//set options
		{	IPMapper.opt = {'title':'1','url':'1', 'favicon':'1','about':'1','latitude':'1','longitude':'1','city':'1','region':'1','country':'1'};
		}
		else
		{	IPMapper.opt = options;
		}

		var errCount;

		for (var i=0;i < dbArr.length;i++) {
			var ipRegex = /^(\S+)$/;
			var ip = dbArr[i].dbhost;
			if ($.trim(ip) !== '' && ipRegex.test(ip)){ //validate IP Address format
				IPMapper.getIPaddMarker(dbArr[i]);
			} else {
				IPMapper.logError('Invalid IP Address! ' + ip);
				$.error('Invalid IP Address! ' + ip);
			}
		}
    },
    // for input in the form of an array of IP addresses
    addIPArray: function(ipArray, options){
		if (typeof options == 'undefined')
		//set options
		{	IPMapper.opt =  {'latitude':'1','longitude':'1','city':'1','region':'1','country':'1'};
		}
		else
		{	IPMapper.opt = options;
		}

		ipArray = IPMapper.uniqueArray(ipArray); //get unique array elements
		//add Map Marker for each IP
		for (var i = 0; i < ipArray.length; i++){
			var ipRegex = /^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/;
		//ipRegex = /^(.+)$/;
		//validate IP Address format
			if($.trim(ipArray[i]) !== '' && ipRegex.test(ipArray[i])){
				IPMapper.getIPaddMarker({ 'dbhost': ipArray[i] });
			} else {
				IPMapper.logError('Invalid IP Address!');
				$.error('Invalid IP Address!');
			}
		}
	},
	getIPaddMarker: function(data){
	// ipRegex = /^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/;

	//ipRegex = /^(.+)$/;
	//if($.trim(ip) != '' && ipRegex.test(ip)){ //validate IP Address format
		var url = encodeURI(IPMapper.baseUrl + data.dbhost + "?callback=?"); //geocoding url
		$.getJSON(url, function(response) { //get Geocoded JSONP data
			if($.trim(response.latitude) !== '' && response.latitude !== '0' && !isNaN(response.latitude)) { //Geocoding successful
				$.extend(data, response);
				if ('region_name' in data) {
					data['region'] = data['region_name'];
				}
				if ('country_name' in data) {
					data['country'] = data['country_name'];
				}
				IPMapper.addMarker(data);
			} else {
				IPMapper.logError('IP Address geocoding failed!');
				$.error('IP Address geocoding failed!');
			}
		})
		.fail(function() {
		//	console.log( "error" );
		});

	},
	addMarker: function(data){
		//{ city: "Burnaby", country_code: "CA", country: "Canada", latitude: 49.25, longitude: -122.95, region_code: "BC", region: "British Columbia" }
		if ('latitude' in data && 'longitude' in data) {
			var latitude = data.latitude;
			var longitude = data.longitude;
			var latlng = new google.maps.LatLng(latitude, longitude);
			var marker = new google.maps.Marker({ //create Map Marker
				map: IPMapper.map,
				draggable: false,
				position: latlng
		    });
			//place Marker on Map
			var contentString = IPMapper.createInfoBox( data );
			IPMapper.placeIPMarker(marker, latlng);
			google.maps.event.addListener(marker, 'click', function() {
				IPMapper.getIPInfoWindowEvent(marker, contentString);
			});
		}
	},
	placeIPMarker: function(marker, latlng){ //place Marker on Map
		marker.setPosition(latlng);
		IPMapper.latlngbound.extend(latlng);
		IPMapper.map.setCenter(IPMapper.latlngbound.getCenter());
		IPMapper.map.fitBounds(IPMapper.latlngbound);
//		google.maps.event.addListener(marker, 'click', function() {
//			IPMapper.getIPInfoWindowEvent(marker, contentString);
//		});
	},
	createInfoBox: function(data){
		// stuff from the IP Geocoder
		var options = IPMapper.opt;
		var titStr = "";
		var str = "";
		var arr = ['city','region','country'];

//		IPMapper.opt =  {'title':'1','url':'1', 'favicon':'1','about':'1','latitude':'1','longitude':'1','city':'1','region':'1','country':'1'};
		if ('title' in options) {
			if (typeof data.url == 'undefined' || data.url.length === 0)
			{	// crap! no proper url
			//	titStr = "<h4><a href='http://" + db.base + "'>";
//				alert("Could not find a proper URL for object!");
			}
			else
			{	titStr = "<h4 style='background: url(https://plus.google.com/_/favicon?domain=" + data.dbhost +
				") left top no-repeat; padding-left: 20px'><a href='" + data.url + "'>";
			}

			if (typeof data.title == 'undefined' || data.title.length === 0)
			{// crstr += '<p>' + db.about + '</p>';
				titStr += data.dbhost + '</a></h4>';
			}
			else
			{	titStr += data.title + '</a></h4>';
			}
			if (typeof data.about != 'undefined' && data.about.length > 0)
			{	titStr += '<p>' + data.about + '</p>';
			}
		}
		str += '<p>';
		// lat and long string
		str += data.latitude + '&deg; N, ' + data.longitude + '&deg; W<br>';

		for (var i = 0; i < arr.length; i++){
			if (arr[i] in options && typeof data[arr[i]] != 'undefined')
			{	str += '<b>' + arr[i].toUpperCase().replace("_", " ") + '</b>: ';
				if (typeof data[arr[i]] == 'undefined') {
					str += " -<br>";
				} else {
					str += data[ arr[i] ] + '<br>';
				}
			}
		}
		str += '</p>';
		titStr += str;
		return titStr;
	},
	getIPInfoWindowEvent: function(marker, contentString){ //open Marker Info Window
		IPMapper.infowindow.close()
		IPMapper.infowindow.setContent(contentString);
		IPMapper.infowindow.open(IPMapper.map, marker);
    },
    uniqueArray: function(inputArray){ //return unique elements from Array
		var a = [];
		for(var i=0; i<inputArray.length; i++) {
			for(var j=i+1; j<inputArray.length; j++) {
				if (inputArray[i] === inputArray[j]) j = ++i;
			}
			a.push(inputArray[i]);
		}
		return a;
	},
	logError: function(error){
		if (typeof console == 'object') { console.error(error); }
	},
};
