<?php
/**
 * Stores the user input to restore the input fields when a back button is pushed.
 * 
 * @author hm
 *
 */
class UserData{
	/// session info. Instance of Session
	var $session;
	/// Filename with path
	var $filename;
	/// true: the data must be written
	var $hasChanged;
	/// the array with the variables
	var $data;
	/** Constructor.
	 * @param $session	the session info
	 */
	function __construct(&$session){
		$this->filename = $session->tempDir . $session->clientAddress . '.data';
		$this->session = $session;
		$this->data = NULL;
		$this->read();
	}
	/** Returns field from the user data.
	 * 
	 * @param $plugin 	the name of the plugin, e.g. "user". This is used for a namespace.
	 * @param $variable	the name of the variable (or field).
	 * @return "": not found. Otherwise: the value of the variable
	 */
	function getValue($plugin, $variable){
		$rc = '';
		$key = "$plugin.$variable";
		if (isset($this->data[$key]))
			$rc = $this->data[$key];
		$this->session->trace(TRACE_FINE, "UserData.getValue($key): '$rc'");
		return $rc; 
	}
	/** Stores the value of a variable (or a field).
	 * 
	 * @param $plugin 	the name of the plugin, e.g. "user". This is used for a namespace
	 * @param $variable	the name of the variable (or field)
	 * @param $value	the value 
	 */
	function setValue($plugin, $variable, $value){
		//$this->session->trace(TRACE_FINE, "UserData.setValue($plugin, $variable, $value)");
		$key = "$plugin.$variable";
		$this->data[$key] = $value;	
		$this->hasChanged = true;
	}
	/** Reads the configuration file.
	 * 
	 * This file stores the field values given by the user.
	 */
	function read(){
		$name = $this->filename;
		$this->data = $this->session->readJavaConfig($name);
		$this->session->trace(TRACE_CONFIG, 'UserData.read(): ' 
			. count($this->data) . ' vars');
	}
	/** Writes the user data.
	 */
	function write(){
		if ($this->hasChanged){
			$this->session->trace(TRACE_CONFIG, 'UserData.write()'
				. count($this->data) . ' vars');
			$fp = fopen($this->filename, 'w');
			foreach ($this->data as $key => $value){
				fprintf($fp, "%s=%s\n", $key, $value);
			}
			fclose($fp);
		}
	}
}
?>