<?php
/**
 * Executes external commands.
 * 
 * External commands will be executed by an external "shell server".
 * This server waits for tasks: It polls a directory for files containing the command.
 * The answer of the server will be written in a file, which is part of the command.
 * 
 * Format of the command file:
 * <pre>
 * answer_file
 * command
 * param1
 * ...
 * </pre>
 * 
 * @author hm
 *
 */
class Executor{
	/// the directory containing the task files, e.g. /tmp/inosid-tasks/
	var $dirTask;
	/// session info
	var $session;
	/// current number for unique filenames
	var $fileNo;
	/** Constructor.
	 * 
	 * @param $session	the session info
	 */
	function __construct(&$session){
		$this->session = $session;
		$this->fileNo = 0;
		$this->dirTask = $session->configuration->getValue('.taskdir');
		if (! empty($this->dirTask) && $this->dirTask[strlen($this->dirTask) - 1] != '/')
			$this->dirTask .= '/';
	}
	/** Executes a command.
	 * 
	 * Creates a task file and wait until the answer file exists.
	 * To avoid invalid data a temparary file is written
	 * and renamed at the end.
	 * 
	 * @param $answer 	the name of the answer file
	 * @param $options	the options for the shell server
	 * @param $command	the command to execute, e.g. SVOPT_DEFAULT
	 * @param $params	NULL or a string or an array of strings
	 * @param $timeout	the maximum count of seconds
	 * @return true: answer file exists. false: timeout reached
	 * 
	 */
	function execute($answer, $options, $command, $params, $timeout){
		$filename = $this->dirTask . $this->session->sessionId 
			. '.' . strval(time()) . '.' 
			. strval(++$this->fileNo) . '.cmd';
		$tmpName = $filename . ".tmp";
		if (file_exists($answer))
			unlink($answer);
		$cmd = "$answer\n$options\n$command";
		if ($params != NULL){
			if (is_array($params))
				$cmd .= "\n" . join("\n", $params);
			else 
				$cmd .= "\n$params";
		}
		$handle = fopen($tmpName, "w");
		fwrite($handle, $cmd);
		fclose($handle);
		rename($tmpName, $filename);
		for ($ii = 0; $ii < $timeout; $ii++){
			sleep(1);
			if (file_exists($answer)){
				break;
			}
		}
		$rc = file_exists($answer);
		return $rc;
	}
}