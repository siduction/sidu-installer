<?php
/**
 * Builds the core content of the network page.
 * Implements a plugin.
 * 
 * @author hm
 */
class NetworkPage extends Page{
	/// Name of the file containing the firmware info created by the script.
	var $firmwareFile;
	/// List of installed firmware modules. Separated by ' '.
	var $installedModules;
	/// Array of uninstalled modules. 
	// Each module is the name and the commands needed for installation
	// Example: rt73usb|apt-get install firmware-ralink|modprobe -r rt73usb|modprobe rt73us 
	var $missingModules;
	/// Node of the last installation log:
	var $nodeLog;
	
	/** Constructor.
	 * 
	 * @param $session
	 */
	function __construct(&$session){
		parent::__construct($session, 'network');
		$this->firmwareFile = $session->tempDir . 'fwdetect.txt';
		$this->setDefaultOption('ssh', 0, true);
		$this->setEmptyToDefault('host', 'network.DEFAULT_HOST');
		$this->nodeLog = 'firmware_log.txt';
		$this->missingModules = null;
		$this->installedModules = null;
		$this->readFirmwareFile();
	}
	/** Calls the script firmware.sh to get firmware info.
	 * 
	 * @param $timeout	number of seconds which the method waits for an answer.
	 * 					If 0 no timeout is set
	 */
	function createFirmwareInfo($timeout){
		$this->session->exec($this->firmwareFile, SVOPT_DEFAULT,
			"firmware",  "info", $timeout);
	}
	/** Reads the file with the output of the script firmware.sh.
	 */
	function readFirmwareFile(){
		if (! file_exists($this->firmwareFile))
			$this->createFirmwareInfo(10);
		if (file_exists($this->firmwareFile)){
			$content = file_get_contents($this->firmwareFile);
			$content = chop($content);
			if (strlen($content) > 3){
				$this->missingModules = explode("\n", $content);
				if (strncmp($this->missingModules[0], '+', 1) == 0){
					$this->installedModules = str_replace('|', ' ', 
						substr($this->missingModules[0], 2));
					unset($this->missingModules[0]);
				}
			}
		}
	}
	/** Builds the core content of the page.
	 * 
	 * Overwrites the method in the baseclass.
	 */
	function build(){
		$this->readContentTemplate();
		$this->buildFirmware();
		$this->fillOptions('ssh');
	}
	/** Constructs the html code of the firmware part.
	 */
	function buildFirmware(){
		if ($this->missingModules == null && $this->installedModules == null)
			$this->clearPart('FOUND_FIRMWARE');
		else{
			$this->readHtmlTemplates();
			$this->replacePartWithTemplate('FOUND_FIRMWARE', 'FOUND_FIRMWARE');
			if ($this->installedModules == null){
				$this->clearPart('INSTALLED_FW');
			} else {
				$this->replacePartWithTemplate('INSTALLED_FW', 'INSTALLED_FW');
				$this->replaceInContent('txt_found_firmware');
				$this->replaceMarker('INSTALLED_MODULES', $this->installedModules);
			}
			if ($this->missingModules == null || $this->installedModules == null)
				$this->clearPart('FW_SEPARATOR');
			else
				$this->replacePartWithTemplate('FW_SEPARATOR', 'FW_SEPARATOR');
			
			if ($this->missingModules == null){
				$this->clearPart('MISSING_FW');
			} else {
				$this->replacePartWithTemplate('MISSING_FW', 'MISSING_FW');
				if (count($this->missingModules) <= 1)
					$this->clearPart('BUTTON_ALL');
				else
					$this->replacePartWithTemplate('BUTTON_ALL', 'BUTTON_ALL');
				$this->setRowCount('fw_modules', 0);
				foreach ($this->missingModules as $ix => $line){
					$pos = strpos($line, '|');
					$row = substr($line, 0, $pos + 1);
					$line = substr($line, $pos + 1);
					$row .= str_replace('|', ' ; ', $line);
					$row .= '|BUTTON_INSTALL_' . strval($ix);
					$this->setRow('fw_modules', $row);
				}
				$this->fillRows('fw_modules');	
			}
			if (! file_exists($this->session->publicDir . $this->nodeLog))
				$this->clearPart('LOG_FIRMWARE');
			else{
				$this->replacePartWithTemplate('LOG_FIRMWARE', 'LOG_FIRMWARE');
				$this->replaceMarker('URL_LOG', $this->session->urlPublicDir . $this->nodeLog);
			}
		}
	}		
	/** Returns an array containing the input field names.
	 * 
	 * @return an array with the field names
	 */
	function getInputFields(){
		$rc = array('host', 'ssh');
		return $rc;
	}
	/** Will be called on a button click.
	 * 
	 * @param $button	the name of the button
	 * @return false: a redirection will be done. true: the current page will be redrawn
	 */
	function onButtonClick($button){
		$redraw = true;
		if (strcmp($button, 'button_next') == 0){
			$ok = $this->isValidContent('host', 'A-Za-z', 'A-Za-z0-9_', true);
			if ($ok)
				$redraw = $this->navigation(false);
		} elseif (strcmp($button, 'button_prev') == 0){
			$redraw = $this->navigation(true);
			//                      123456789 12345			
		} elseif (strncmp($button, 'button_install_', 15) == 0){
			$modules = ""; 
			if (strcmp ($button, 'button_install_all') == 0){
				foreach ($this->missingModules as $ix => $line){
					$pos = strpos($line, '|');
					$modules .= ';' . substr($line, 0, $pos);
				}
				$modules = substr($modules, 1);
			} else {
				$ix = intval(substr($button, 15));
				$line = $this->missingModules[$ix];
				$pos = strpos($line, '|');
				$modules .= substr($line, 0, $pos);
			}
			$node = 'fw_install_' . strval(time()) . '.txt';
			$answer = $this->session->publicDir . $node;
			$params = array();
			$params[] = 'install';
			$params[] = $modules; 
			$program = 'firmware';
			$progress = null;
			$this->session->exec($answer, SVOPT_DEFAULT,
				$program, $params, 0);
			$description = "";
			$redraw = $this->startWait($answer, $program, $description, $progress);
			
		} else {
			$this->session->log("unknown button: $button");
		}
		return $redraw;
	} 
}
?>