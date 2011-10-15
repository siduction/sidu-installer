<?php
/**
 * Manages the global configuration data.
 * 
 * @author hm
 */
class Configuration{
	/// session info. Instance of Session
	var $session;
	/// filename with path
	var $filename;
	/// the array with the configuration variables
	var $data;
	/// placeholders in configurations.
	var $makros;
	/// replacements for the placeholders.
	var $replacements;
	
	/** Constructor.
	 * 
	 * @param $session	the session info
	 */
	function __construct(&$session){
		$this->filename = $session->findFileByLanguage('inosid.conf', 
			$session->language);
		$this->makros = NULL;
		$this->session = $session;
		$this->read();
		
	}
	/** Returns field from the configuration data.
	 * 
	 * @param $variable	the name of the variable (or field).
	 * @return "": not found. Otherwise: the value of the variable
	 */
	function getValue($variable){
		$rc = "";
		if (isset($this->data[$variable]))
		{
			if ($this->makros == null && $this->session->tempDir != NULL){
				$this->makros = array('${home}', '${sessionid}', 
					'${tempdir}');
				$this->replacements = array($this->session->homeDir,
					$this->session->sessionId, 
					$this->session->tempDir);
			}
			$rc = $this->data[$variable];
			if ($this->makros != null)
				$rc = str_replace($this->makros, $this->replacements, $rc);
			else{
				$rc = str_replace('${home}', $this->session->homeDir, $rc);
				$rc = str_replace('${sessionid}', $this->session->sessionId, $rc);
			}
		}
		return $rc; 
	}
	/** Reads the configuration file.
	 * 
	 * This file contains global configuration data.
	 * The syntax is "java configuration data":
	 * Each line contains a variable definition: key=value
	 */
	function read(){
		$this->data = $this->session->readJavaConfig($this->filename);
		$this->session->trace(TRACE_CONFIG, 'Config.read(): ' 
			. count($this->data) . ' vars');
	}
}
?>