// package main

// import (
// 	"encoding/json"
// 	"fmt"
// 	"io/ioutil"
// 	"log"
// 	"os"
// 	"strings"

// 	// lumberjack "gopkg.in/natefinch/lumberjack.v2"
// 	// "bytes"
// 	// "encoding/json"
// 	// "fmt"
// 	// "log"
// 	"net/http"
// 	// "os"
// 	// "sync"
// 	// "time"
// 	"github.com/fluent/fluent-bit-go/output"
// 	lumberjack "gopkg.in/natefinch/lumberjack.v2"
// 	//lumberjack "gopkg.in/natefinch/lumberjack.v2"
// 	// lumberjack "gopkg.in/natefinch/lumberjack.v2"
// 	// "k8s.io/client-go/kubernetes"
// 	// lumberjack "gopkg.in/natefinch/lumberjack.v2"
// 	// metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
// 	// "k8s.io/client-go/kubernetes"
// 	// "k8s.io/client-go/rest"
// )

// //env varibale which has ResourceId for LA
// // const ResourceIdEnv = "AKS_RESOURCE_ID"

// //env variable which has ResourceName for NON-AKS
// // const ResourceNameEnv = "ACS_RESOURCE_NAME"

// const TokenResourceUrl = "https://monitoring.azure.com/"
// // const GrantType = "client_credentials"
// const AzureJsonPath = "/etc/kubernetes/host/azure.json"

// const PostRequestUrlTemplate = "https://%{aks_region}.monitoring.azure.com%{aks_resource_id}/metrics"
// const AadTokenUrlTemplate = "https://login.microsoftonline.com/%{tenant_id}/oauth2/token"

// // msiEndpoint is the well known endpoint for getting MSI authentications tokens
// const MsiEndpointTemplate = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&client_id=%{user_assigned_client_id}&resource=%{resource}"
// const UserAssignedClientId = os.Getenv("USER_ASSIGNED_IDENTITY_CLIENT_ID")

// // 	  const      @@plugin_name = "AKSCustomMetricsMDM"
// // 	  const      @@record_batch_size = 2600

// // 	  const      @@tokenRefreshBackoffInterval = 30

// // 	  const      @data_hash = {}
// // 	  const      @parsed_token_uri = nil
// // 	  const      @http_client = nil
// // 	  const     @last_post_attempt_time = Time.now
// // 	  const     @first_post_attempt_made = false
// const CanSendDataToMdm = true

// // 	  const      @last_telemetry_sent_time = nil
// //       # Setting useMsi to false by default
// const useMsi = false

// // 	  const     @get_access_token_backoff_expiry = Time.now

// // var (
// // 	// ImageIDMap caches the container id to image mapping
// // 	ImageIDMap map[string]string
// // 	// NameIDMap caches the container it to Name mapping
// // 	NameIDMap map[string]string
// // 	// StdoutIgnoreNamespaceSet set of  excluded K8S namespaces for stdout logs
// // 	StdoutIgnoreNsSet map[string]bool
// // 	// StderrIgnoreNamespaceSet set of  excluded K8S namespaces for stderr logs
// // 	StderrIgnoreNsSet map[string]bool
// // 	// DataUpdateMutex read and write mutex access to the container id set
// // 	DataUpdateMutex = &sync.Mutex{}
// // 	// ContainerLogTelemetryMutex read and write mutex access to the Container Log Telemetry
// // 	ContainerLogTelemetryMutex = &sync.Mutex{}
// // 	// ClientSet for querying KubeAPIs
// // 	ClientSet *kubernetes.Clientset
// // 	// Config error hash
// // 	ConfigErrorEvent map[string]KubeMonAgentEventTags
// // 	// Prometheus scraping error hash
// // 	PromScrapeErrorEvent map[string]KubeMonAgentEventTags
// // 	// EventHashUpdateMutex read and write mutex access to the event hash
// // 	EventHashUpdateMutex = &sync.Mutex{}
// // )

// var (
// CachedAccessToken string
// GetAccessTokenBackoffExpiry = time.Now()
// TokenExpiryTime = time.Now()
// TokenUri string
// )

// var (
// 	// FLBLogger stream
// 	FLBLogger = createLogger()
// 	// Log wrapper function
// 	Log = FLBLogger.Printf
// )

// func createLogger() *log.Logger {
// 	var logfile *os.File
// 	path := "/var/opt/microsoft/docker-cimprov/log/fluent-bit-out-oms-runtime.log"
// 	if _, err := os.Stat(path); err == nil {
// 		fmt.Printf("File Exists. Opening file in append mode...\n")
// 		logfile, err = os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0600)
// 		if err != nil {
// 			SendException(err.Error())
// 			fmt.Printf(err.Error())
// 		}
// 	}

// 	if _, err := os.Stat(path); os.IsNotExist(err) {
// 		fmt.Printf("File Doesnt Exist. Creating file...\n")
// 		logfile, err = os.Create(path)
// 		if err != nil {
// 			SendException(err.Error())
// 			fmt.Printf(err.Error())
// 		}
// 	}

// 	logger := log.New(logfile, "", 0)

// 	logger.SetOutput(&lumberjack.Logger{
// 		Filename:   path,
// 		MaxSize:    10, //megabytes
// 		MaxBackups: 1,
// 		MaxAge:     28,   //days
// 		Compress:   true, // false by default
// 	})

// 	logger.SetFlags(log.Ltime | log.Lshortfile | log.LstdFlags)
// 	return logger
// }

// // Method to get access token
// func GetAccessToken() {
// 	if (time.Now() > GetAccessTokenBackoffExpiry) {
// 	httpAccessToken = nil
// 	retries = 0
// 	begin
// 	  if CachedAccessToken == nil ||
// 	  CachedAccessToken == "" ||
// 	  (time.Now() + 5 * time.Minute > TokenExpiryTime) {
// 	  // Refresh token 5 minutes from expiration
// 		Log("Refreshing access token for mdm go plugin..")

// 		if useMsi
// 		  Log("Using msi to get the token to post MDM data")
// 	SendEvent("AKSCustomMetricsMDMGoPluginStart", map[])
// 		//   ApplicationInsightsUtility.sendCustomEvent("AKSCustomMetricsMDMToken-MSI", {})
// 		//   Log("Opening TCP connection")
// // Basic HTTP GET request
// resp, err := http.Get(TokenUri)
// if err != nil {
// 	message := fmt.Sprintf("Error getting access token using SP %s \n", err.Error())
// 	Log(message)
// 	SendException(message)
// }
// defer resp.Body.Close()

// // Read body from response
// body, err := ioutil.ReadAll(resp.Body)
// if err != nil {
// 	message := fmt.Sprintf("Error reading response while getting access token using SP %s \n", err.Error())
// 	Log(message)
// 	SendException(message)
// }

// fmt.Printf("%s\n", body)

// 		  http_access_token = Net::HTTP.start(@parsed_token_uri.host, @parsed_token_uri.port, :use_ssl => false)
// 		  token_request = Net::HTTP::Get.new(@parsed_token_uri.request_uri)
// 		  token_request["Metadata"] = true
// 		else
// 		  @log.info "Using SP to get the token to post MDM data"
// 		  ApplicationInsightsUtility.sendCustomEvent("AKSCustomMetricsMDMToken-SP", {})
// 		  @log.info "Opening TCP connection"
// 		  http_access_token = Net::HTTP.start(@parsed_token_uri.host, @parsed_token_uri.port, :use_ssl => true)
// 		  # http_access_token.use_ssl = true
// 		  token_request = Net::HTTP::Post.new(@parsed_token_uri.request_uri)
// 		  token_request.set_form_data(
// 			{
// 			  "grant_type" => @@grant_type,
// 			  "client_id" => @data_hash["aadClientId"],
// 			  "client_secret" => @data_hash["aadClientSecret"],
// 			  "resource" => @@token_resource_url,
// 			}
// 		  )
// 		end

// 		@log.info "making request to get token.."
// 		token_response = http_access_token.request(token_request)
// 		# Handle the case where the response is not 200
// 		parsed_json = JSON.parse(token_response.body)
// 		@token_expiry_time = Time.now + @@tokenRefreshBackoffInterval * 60 # set the expiry time to be ~thirty minutes from current time
// 		@cached_access_token = parsed_json["access_token"]
// 	  @log.info "Successfully got access token"
// 		}
// 	rescue => err
// 	  @log.info "Exception in get_access_token: #{err}"
// 	  if (retries < 2)
// 		retries += 1
// 		@log.info "Retrying request to get token - retry number: #{retries}"
// 		sleep(retries)
// 		retry
// 	  else
// 	  @get_access_token_backoff_expiry = Time.now + @@tokenRefreshBackoffInterval * 60
// 	  @log.info "@get_access_token_backoff_expiry set to #{@get_access_token_backoff_expiry}"
// 	  ApplicationInsightsUtility.sendExceptionTelemetry(err, {"FeatureArea" => "MDM"})
// 	  end
// 	ensure
// 	  if http_access_token
// 		@log.info "Closing http connection"
// 		http_access_token.finish
// 	  end
// 	end
// 		}
//   return CachedAccessToken
// end
// }

// // InitializeMdmPlugin reads and populates plugin configuration
// func InitializeMdmPlugin(pluginConfPath string, agentVersion string) {
// 	//Read azure json file to get the Service Principal value
// 	azureJSONFile, err := ioutil.ReadFile(AzureJsonPath)
// 	if err != nil {
// 		message := fmt.Sprintf("Error while reading azure json file", err.Error())
// 		Log(message)
// 		SendException(message)
// 		return output.FLB_OK
// 	}
// 	var result map[string]interface{}
// 	err := json.Unmarshal([]byte(ToString(azureJSONFile)), &result)

// 	if err != nil {
// 		message := fmt.Sprintf("Error while unmarshaling azure json file", err.Error())
// 		Log(message)
// 		SendException(message)
// 		return output.FLB_OK
// 	}

// 	aksResourceID := os.Getenv("AKS_RESOURCE_ID")
// 	aksRegion := os.Getenv("AKS_REGION")

// 	if aksResourceID == "" {
// 		message := fmt.Sprintf("Environment Variable AKS_RESOURCE_ID is not set.. ")
// 		Log(message)
// 		CanSendDataToMdm = false
// 	}
// 	end
// 	if aksRegion == "" {
// 		message := fmt.Sprintf("Environment Variable AKS_REGION is not set.. ")
// 		Log(message)
// 		CanSendDataToMdm = false
// 	} else {
// 		aksRegion = strings.Replace(aksRegion, " ", "", -1)
// 	}

// 	if CanSendDataToMdm {
// 	Log("MDM Metrics supported in", aksRegion, "region")

// 	postRequestUrl := strings.Replace(PostRequestUrlTemplate, "aks_region", aksRegion, -1)
// 	postRequestUrl = strings.Replace(PostRequestUrlTemplate, "aks_resource_id", aksResourceID, -1)

// 	// @post_request_uri = URI.parse(@@post_request_url)
// 	// @http_client = Net::HTTP.new(@post_request_uri.host, @post_request_uri.port)
// 	// @http_client.use_ssl = true
// 	// @log.info "POST Request url: #{@@post_request_url}"

// 	// Send telemetry to AppInsights resource
// 	SendEvent("AKSCustomMetricsMDMGoPluginStart", map[])

// 	// Check to see if SP exists, if it does use SP. Else, use msi
// 	spClientId := result["aadClientId"]
// 	spClientSecret := result["aadClientSecret"]

// 	if spClientId != nil &&
// 		spClientId != "" &&
// 		strings.ToLower(spClientId) != "msi" {
// 	  useMsi = false
// 	//   aad_token_url = @@aad_token_url_template % {tenant_id: @data_hash["tenantId"]}
// 	TokenUri = strings.Replace(AadTokenUrlTemplate, "tenant_id", result["tenantId"], -1)
// 	//   @parsed_token_uri = URI.parse(aad_token_url)
// 	} else {
// 	  useMsi = true
// 	  TokenUri = strings.Replace(MsiEndpointTemplate, "user_assigned_client_id", UserAssignedClientId, -1)
// 	  TokenUri = strings.Replace(MsiEndpointTemplate, "token_resource_url", TokenResourceUrl , -1)
// 	//   @parsed_token_uri = URI.parse(msi_endpoint)
// 	}

// 	CachedAccessToken = GetAccessToken
// 	}
// }
