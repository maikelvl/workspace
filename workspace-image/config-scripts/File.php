<?php

class File {

	static public function write($file, $data)
	{
		$handle = fopen($file, "w");
        $success = fwrite($handle, $data, strlen($data));
        fclose($handle);
        if ($success)
        {
        	Logger::log("File written: $file");
        }
        else
        {
        	throw new Exception("Error writing to file: $file", 1);
        }
	}

	static public function read($file)
	{
		if ( ! $handle = fopen($file, "r"))
		{
			throw new Exception("File: $file not found");
		}
		$contents = fread($handle, filesize($file));
		fclose($handle);
		return $contents;
	}

	static public function directory_map($source_dir, $directory_depth = 0, $hidden = FALSE)
	{
	    if ($fp = @opendir($source_dir))
	    {
	        $filedata   = array();
	        $new_depth  = $directory_depth - 1;
	        $source_dir = rtrim($source_dir, DIRECTORY_SEPARATOR).DIRECTORY_SEPARATOR;

	        while (FALSE !== ($file = readdir($fp)))
	        {
	            // Remove '.', '..', and hidden files [optional]
	            if ($file === '.' OR $file === '..' OR ($hidden === FALSE && $file[0] === '.'))
	            {
	                continue;
	            }

	            is_dir($source_dir.$file) && $file .= DIRECTORY_SEPARATOR;

	            if (($directory_depth < 1 OR $new_depth > 0) && is_dir($source_dir.$file))
	            {
	                $filedata[$file] = File::directory_map($source_dir.$file, $new_depth, $hidden);
	            }
	            else
	            {
	                $filedata[] = $file;
	            }
	        }

	        closedir($fp);
	        return $filedata;
	    }

	    return FALSE;
	}

	static public function write_file($path, $data, $mode = 'wb')
	{
	    if ( ! $fp = @fopen($path, $mode))
	    {
	        return FALSE;
	    }

	    flock($fp, LOCK_EX);

	    for ($result = $written = 0, $length = strlen($data); $written < $length; $written += $result)
	    {
	        if (($result = fwrite($fp, substr($data, $written))) === FALSE)
	        {
	            break;
	        }
	    }

	    flock($fp, LOCK_UN);
	    fclose($fp);

	    return is_int($result);
	}

	static public function delete_files($path, $del_dir = FALSE, $htdocs = FALSE, $_level = 0)
	{
	    // Trim the trailing slash
	    $path = rtrim($path, '/\\');

	    if ( ! $current_dir = @opendir($path))
	    {
	        return FALSE;
	    }

	    while (FALSE !== ($filename = @readdir($current_dir)))
	    {
	        if ($filename !== '.' && $filename !== '..')
	        {
	            if (is_dir($path.DIRECTORY_SEPARATOR.$filename) && $filename[0] !== '.')
	            {
	                File::delete_files($path.DIRECTORY_SEPARATOR.$filename, $del_dir, $htdocs, $_level + 1);
	            }
	            elseif ($htdocs !== TRUE OR ! preg_match('/^(\.htaccess|index\.(html|htm|php)|web\.config)$/i', $filename))
	            {
	                @unlink($path.DIRECTORY_SEPARATOR.$filename);
	            }
	        }
	    }

	    closedir($current_dir);

	    return ($del_dir === TRUE && $_level > 0)
	        ? @rmdir($path)
	        : TRUE;
	}

	static public function rrmdir($dir)
	{
	    if (is_dir($dir))
	    {
	        $objects = scandir($dir);
	        foreach ($objects as $object)
	        {
	            if ($object != "." && $object != "..")
	            {
	                if (filetype($dir."/".$object) == "dir")
	                {
	                    File::rrmdir($dir."/".$object);
	                }
	                else
	                {
	                    unlink($dir."/".$object);
	                }
	            }
	        }
	        reset($objects);
	        rmdir($dir);
	    }
	}	
}