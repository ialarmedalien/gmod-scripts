<?php
/*
	Script to save us from having to do a load of geocoding
	Check when the GMOD Users wiki page was last updated
	Compare timestamp to stored timestamp
	if not equal, update our stored data with new data from the wiki,
	including geocoding

	Queries the telize server to get geo data.

	Requires simple_html_dom.php, from http://simplehtmldom.sourceforge.net
*/

// set this for troubleshooting
// ini_set('display_errors', 'On');
// error_reporting(E_ALL | E_STRICT);

// turn verbose mode on or off:
// $verbose = true;
$verbose = false;

include('simple_html_dom.php');

// local file for storing wiki data (make sure apache can write to the dir!)
$f_name = '/www/sites/test/wiki_data.json';
$base_url = 'http://gmod.org/mediawiki/api.php?format=json&action=';
$touch_q  = 'query&titles=GMOD%20Users&prop=info';
$content_q = 'parse&page=GMOD%20Users';

/**
 *  function erratum
 *  shortcut to write out an error message at the appropriate level
 *  used where error may be one of several levels
 *  @param string $error_level - notice / warn / error (optional)
 *  @param string $error_message - the message itself
 */

function erratum( $error_level = 'notice', $error_message = '') {
	if (strlen($error_message) === 0)
	{	$error_message = "Unspecified error occurred!\n";
	}
	switch ($error_level) {
		case 'notice':
			trigger_error($error_message, E_USER_NOTICE);
		case 'warn':
			trigger_error($error_message, E_USER_WARNING);
		case 'error':
			trigger_error($error_message, E_USER_ERROR);
		default:
			if ($GLOBALS['verbose'] == true) // global $verbose)
			{
				echo $error_message . "\n";
			}
		break;
	}
}

/**
 *  function go_curling
 *  Executes a curl request and checks the response is JSON.
 *  @param string $url - the URL to query
 *  @param string $error_level -
 *  @param string $error_message -
 */

function go_curling( $url, $error_level = 'notice', $error_message = '') {
	$c = curl_init( $url );
	curl_setopt($c, CURLOPT_RETURNTRANSFER, 1);
	// check for curl execution errors
	if (! $resp = curl_exec($c))
	{	erratum($error_level, $error_message . "Curl error: " . curl_error($c) . "\n");
		return false;
	}
	curl_close($c);

	$json = json_decode($resp, true);

	// make sure we've got json as a response, not a 404 error page
	if (function_exists('json_last_error()'))
	{	if (json_last_error() == 'JSON_ERROR_NONE')
		{	// decoding was ok
		}
		else
		{	$error = 1;
			$msg = $error_message . "JSON decoding error: " . json_last_error . "\n";
		}
	}

// all our queries should return an array of some sort.
	if (! is_array($json))
	{	$error = 1;
		if (! isset($msg) )
		{	$msg = $error_message;
		}
		$msg .= "JSON issue: no array found! Response:\n" . $json . "\n";
	}

	if (isset($error))
	{	erratum($error_level, $msg);
	}

//	if ($GLOBALS['verbose']) {
//		echo "Query URL: $url\nResponse: ";
//		print_r($json);
//	}
	return $json;
}

// check the date that the user page was modified.
$result = go_curling($base_url . $touch_q, 'error', "Could not retrieve GMOD Users page modification date\n");

if (isset($result['query']['pages'])) {
	foreach ($result['query']['pages'] as $key => $value) {
		if ($value['title'] == 'GMOD Users') {
			$wiki_touched = $value['touched'];
		}
	}
}

// die if we can't get the wiki touched date as it means something has gone
// very wrong!
if (! isset($wiki_touched)) {
	trigger_error('GMOD Users page metadata in unexpected format!', E_USER_ERROR);
}

if ($verbose) {
	echo "wiki last touched at $wiki_touched\n";
}

// check for a file of stored wiki data.
// if exists, open it and read the contents to find out when it was generated

if (file_exists($f_name) && is_readable($f_name)) {
	$file_contents = file_get_contents($f_name);
	if (! $file_contents) {
		// no file contents!
		if ($verbose)
		{	echo "File $f_name is empty. Getting data from wiki.\n";
		}
	} else {
		$decoded = html_entity_decode($file_contents);
		$w_data = json_decode($decoded, true);
		if (isset($w_data['data']) && count($w_data['data']) > 10)
		{	$file_touched = $w_data['timestamp'];
		}
	}
} else {
	if ($verbose)
	{	echo "$f_name was not found.\n";
	}
}

// the wiki has been modified! let's get the new page from the server
if (! isset($file_touched)  ||  $wiki_touched != $file_touched )
{	$contents = go_curling($base_url . $content_q, 'error', "Could not retrieve GMOD Users page contents.\n");

	if (! isset($contents['parse']['text']['*'])) {
	// no page contents!!
		trigger_error('Could not retrieve GMOD Users page contents', E_USER_ERROR);
	}

	$page = $contents['parse']['text']['*'];
	// isolate the table.
	preg_match('/(<table.*?table>)/sm', $page, $matches);
	if (isset($matches[0]))
	{	// remove the table head
		$table = preg_replace('/(<thead.*?<\/thead>)/sm', '', $matches[0]);
		// remove the references
		$table = preg_replace('/<sup .*?sup>/sm', '', $table);
//		if ($verbose)
//		{	echo "Table now:\n";
//			print_r($table);
//		}
		$html = new simple_html_dom();
		$html->load($table);

		foreach($html->find('tr') as $tr)
		{	$temp_url = $tr->find('td',0)->find('a',0)->href;

			if (! isset($temp_url)) {
				trigger_error('No URL for ' . $tr->find('td',0), E_USER_NOTICE);
				continue;
			}

			$users[$temp_url] = array(
				'dbhost' => parse_url($temp_url, PHP_URL_HOST),
				'url' => $temp_url,
				'title' => trim($tr->find('td',1)->innertext),
				'about' => trim($tr->find('td',2)->innertext)
			);
		}
		// free up the memory
		$html->clear();
		unset($html);

		// now find the IP address corresponding to each URL
		// and the geo information
		$c = 0;
		foreach ($users as $hostname => $u)
		{	if ($verbose)
			{	echo "Looking at " . $u['dbhost'] . "...\n";
			}
			$hosts = gethostbynamel($u['dbhost']);
			if (is_array($hosts)) {
				// use the first IP address
				if ($verbose && count($hosts) > 1) {
					echo "Found " . count($hosts) . " IP addresses for " . $u['dbhost'] . "\n";
					print_r($hosts);
				}
				$u['ip'] = $hosts[0];
			}
			else {
				trigger_error("Cannot find IP for " . $u['dbhost'], E_USER_NOTICE);
				continue;
			}
			// get the geo information
			// http://www.telize.com/geoip/
			$geodata = go_curling("http://www.telize.com/geoip/" . $u['ip'], 'warn', "No geo data for " . $u['dbhost'] . "\n");
			if (isset($geodata['code'])) {
				// error!
				trigger_error("Error finding geo info for " . $u['dbhost'] . ": " . $geodata['code'] . "! " . $geodata['message'], E_USER_NOTICE);
			} else {
				if ($verbose && $c < 5) {
					print_r($geodata);
				}
				$props = array('country', 'region', 'city', 'latitude', 'longitude');
				foreach ($props as $p) {
					if (isset ($geodata[$p]))
					{	if (preg_match('/[alnum]/', $geodata[$p]) === 1)
						{	if ($verbose && $c < 5)
							{	echo "Passed regex test: $p, " . $geodata[$p] . "\n";
							}
						}
						$u[$p] = $geodata[$p];
					}
				}
			}
			if ($verbose && $c < 5)
			{	echo "U now: ";
				print_r($u);
			}
			if ($verbose) {
				echo "Finished!\n";
			}
			$users[$hostname] = $u;
			$c++;
		}
	}
	else
	{	 trigger_error('Could not find table on GMOD Users page', E_USER_ERROR);
	}

	// now let's store the data in a file.
	$wiki_data = json_encode( array( 'timestamp' => $wiki_touched, 'data' => $users ) );

	if ($verbose) {
		echo "Finished collecting wiki data.\n";
	}

	if (file_put_contents($f_name . ".temp", $wiki_data)) {
		// success! replace $f_name with $f_name.temp
		rename($f_name.".temp", $f_name);
		if ($verbose) {
			echo "Finished writing file $f_name.\n";
		}
	} else {
		trigger_error("Could not write file $f_name.temp!\n", E_USER_WARNING);
		if ($verbose) {
			echo "Could not write to " . $f_name . ".temp!\nJSON data:\n$wiki_data\n";
		}
	}
}
