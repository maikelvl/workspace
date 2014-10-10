<?php

class Curl {

	private $url = FALSE;
	private $uri = FALSE;
	private $query = array();
	private $headers = array();
	private $data = array();
	private $method = '';

	public function url($url)
	{
		$this->url = trim($url, '/');
		return $this;
	}

	public function uri($uri)
	{
		$this->uri = trim($uri, '/');
		return $this;
	}

	public function query($k, $v)
	{
		$this->query[$k] = $v;
		return $this;
	}

	public function header($k, $v = FALSE)
	{
		$this->headers[] = $v === FALSE ? $k : trim($k).': '.trim($v);
		return $this;
	}

	public function data($data, $is_json = FALSE)
	{
		if ($is_json)
		{
			$data = json_encode($data);
			$this->content_length(strlen($data));
		}
		$this->data = $data;
		return $this;
	}

	public function post()
	{
		$this->method = 'post';
	    return $this->request();
	}

	public function get()
	{
	    $this->method = 'get';
	    return $this->request();
	}

	public function put()
	{
		$this->method = 'put';
	    return $this->request();
	}

	public function delete()
	{
	    $this->method = 'delete';
	    return $this->request();
	}

	private function content_length($length)
	{
		$this->header('Content-Length', $length);
		return $this;
	}

	private function request()
	{
		if ( ! $this->url)
	    {
	    	throw new Exception("Missing URL", 1);
	    }

	    if ( ! $this->uri)
	    {
	    	throw new Exception("Missing URI", 1);
	    }

	    $url = $this->url.'/'.$this->uri;
	    if ($this->query)
	    {
	    	$query = array();
	    	foreach ($this->query as $k => $v)
	    	{
	    		$query[] = $k.'='.$v;
	    	}
	    	$url = trim($url, '/')."?".implode('&', $query);
	    }

	    $curl_options[CURLOPT_URL] = $url;
	    $curl_options[CURLOPT_HTTPHEADER] = array_merge(array("Content-Type: application/json"), $this->headers);

	    switch (strtolower($this->method)) {
	        case 'get':
	            $curl_options[CURLOPT_HTTPGET] = TRUE;
	            break;
	        case 'post':
	            $curl_options[CURLOPT_POST] = TRUE;
	            break;
	        case 'put':
	            $curl_options[CURLOPT_PUT] = TRUE;
	            break; 
	        case 'delete':
	            break;
	    }

	    $curl_options[CURLOPT_CUSTOMREQUEST] = strtoupper($this->method);
	    $curl_options[CURLOPT_RETURNTRANSFER] = TRUE;
	    if ($this->data)
	    {
	        $curl_options[CURLOPT_POSTFIELDS] = $this->data;
	    }
	   	$curl_options[CURLOPT_USERAGENT] = gethostname();
	    // Send request and wait for response
	    $handle = curl_init();
	    Logger::log($curl_options[CURLOPT_CUSTOMREQUEST].' '.$curl_options[CURLOPT_URL]);
	    curl_setopt_array($handle, $curl_options);
	    $res = curl_exec($handle);

	    if ($res === FALSE)
	    {
	    	throw new Exception("Error Processing Request: ".curl_error($handle), 1);
	    }

	    curl_close($handle);

	    if ($json = json_decode($res, TRUE))
	    {
	    	Logger::log("RES ".str_replace("\n", '',$res));
	    	$res = $json;
	    }

	    return $res;
	}

}