<?php
/**
 * Builds the core content of the bootloader/timezone page.
 * Implements a plugin.
 * 
 * @author hm
 */
class BootPage extends Page{
	/// The answer file from the shell server.
	var $fileCurrentZone;
	/// The answer file from the shell server.
	var $fileTimeZone;
	/** Constructor.
	 * 
	 * @param $session
	 */
	function __construct(&$session){
		parent::__construct($session, 'boot');
		$this->setDefaultOption('loader', 1, true);
		$this->setDefaultOption('target', 0, true);
		$filename = $this->getConfiguration('file.demo.currentzone');
		if (! file_exists($filename))
			$filename = $this->getConfiguration('file.currentzone');
		$this->fileCurrentZone = $filename;

		$filename = $this->getConfiguration('file.demo.timezoneinfo');
		if (! file_exists($filename))
			$filename = $this->getConfiguration('file.timezoneinfo');
		$this->fileTimeZone = $filename;
			
		$this->checkTimeZoneFiles();
	}
	/** Tests whether the time zone files must be created/read.
	 */
	function checkTimeZoneFiles(){
		$regions = $this->getUserData('opt_region');
		if (strpos($regions, OPT_SEPARATOR) <= 0){
			if (! file_exists($this->fileCurrentZone)){
				$this->session->exec($this->fileCurrentZone, SVOPT_DEFAULT, 
					"timezoneinfo",  "current", 0);
			}
			if (! file_exists($this->fileTimeZone)){
				$this->session->exec($this->fileTimeZone, SVOPT_DEFAULT,
					"timezoneinfo",  "all", 0);
			}
			$this->prepareTimezone();
		}
	}
	/** Reads the timezone file from the shell server and build the internal data structures.
	 */ 
	function prepareTimezone(){
		if (! file_exists($this->fileCurrentZone)){
			$currentRegion = "Europe";
			$currentCity = "Berlin";
		} else {
			$value = chop($this->session->readFile($this->fileCurrentZone));
			list($currentRegion, $currentCity) = explode('/', $value);
		}
		$value = $this->getUserData('region_' . $currentRegion);
		if (empty($value))
			$this->setUserData('region_' . $currentRegion, $currentRegion);
		$regions = '';
		if (! file_exists($this->fileTimeZone)){
			$regions = $currentRegion;
			$cities = $currentCity;
		} else {
			$regionlist = array();
			$file = file($this->fileTimeZone);
			while (list($key, $line) = each($file)) {
				$line = chop($line);
				// Format: region/city
				list($region, $city) = explode('/', $line);
				if (! empty($city)){
					if (isset($regionlist[$region]))
						$regionlist[$region] .= OPT_SEPARATOR . $city;
					else {
						$regionlist[$region] = $city;
						$regions .= OPT_SEPARATOR . $region;
					}
				}
			}
			// remove first separator:
			$regions = substr($regions, 1);
			
			foreach ($regionlist as $region => $value){
				$this->setUserData('region_' . $region, $value);
			}
		}
		$cities = $this->getUserData('region_' . $currentRegion); 
		$this->setUserData('opt_region', $regions);
		$this->setUserData('opt_city', $cities);
		$this->setUserData('region', $currentRegion);
		$this->setUserData('city', $currentCity);
	}
	/** Builds the core content of the page.
	 * 
	 * Overwrites the method in the baseclass.
	 */
	function build(){
		$this->readContentTemplate();
		$this->fillOptions('loader');
		$this->fillOptions('target');
		$this->checkTimeZoneFiles();
		$this->fillOptions('region', true);
		$this->fillOptions('city', true);
	}		
	/** Returns an array containing the input field names.
	 * 
	 * @return an array with the field names
	 */
	function getInputFields(){
		$rc = array('loader', 'target', 'region', 'city');
		return $rc;
	}
	/** Handles the button click of "refresh".
	 */
	function refreshTimeZone(){
		$this->checkTimeZoneFiles();
		$currentRegion = $this->session->getField('region');
		$cities = $this->getUserData('region_' . $currentRegion);
		if (! empty($cities))
			$this->setUserData('opt_city', $cities);
	}
	/** Will be called on a button click.
	 * 
	 * @param $button	the name of the button
	 * @return false: a redirection will be done. true: the current page will be redrawn
	 */
	function onButtonClick($button){
		$redraw = true;
		$this->setSelectionField('loader');
		$this->setSelectionField('target');
		$this->setSelectionField('region');
		$this->setSelectionField('city');
		if (strcmp($button, 'button_refresh') == 0){
			$this->refreshTimeZone();
		} elseif (strcmp($button, 'button_prev') == 0){
			$redraw = $this->navigation(true);
		} elseif (strcmp($button, 'button_next') == 0){
			$timezone = $this->session->getField('region') . '/' . $this->session->getField('city');
			$this->session->exec(NULL, SVOPT_DEFAULT, 
					'timezoneinfo', array('set',  $timezone), 0);
			$redraw = $this->navigation(false);
		} else {
			$this->session->log("unknown button: $button");
		}
		return $redraw;
	} 
}
?>