package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strings"

	// lumberjack "gopkg.in/natefinch/lumberjack.v2"
	// "bytes"
	// "encoding/json"
	// "fmt"
	// "log"
	// "net/http"
	// "os"
	// "sync"
	// "time"
	"github.com/fluent/fluent-bit-go/output"
	lumberjack "gopkg.in/natefinch/lumberjack.v2"
	//lumberjack "gopkg.in/natefinch/lumberjack.v2"
	// lumberjack "gopkg.in/natefinch/lumberjack.v2"
	// "k8s.io/client-go/kubernetes"
	// lumberjack "gopkg.in/natefinch/lumberjack.v2"
	// metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	// "k8s.io/client-go/kubernetes"
	// "k8s.io/client-go/rest"
)

//env varibale which has ResourceId for LA
// const ResourceIdEnv = "AKS_RESOURCE_ID"

//env variable which has ResourceName for NON-AKS
// const ResourceNameEnv = "ACS_RESOURCE_NAME"

const TokenResourceUrl = "https://monitoring.azure.com/"
// const GrantType = "client_credentials"
const AzureJsonPath = "/etc/kubernetes/host/azure.json"

const PostRequestUrlTemplate = "https://%{aks_region}.monitoring.azure.com%{aks_resource_id}/metrics"
const AadTokenUrlTemplate = "https://login.microsoftonline.com/%{tenant_id}/oauth2/token"

// msiEndpoint is the well known endpoint for getting MSI authentications tokens
const MsiEndpointTemplate = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&client_id=%{user_assigned_client_id}&resource=%{resource}"
const UserAssignedClientId = os.Getenv("USER_ASSIGNED_IDENTITY_CLIENT_ID")

// 	  const      @@plugin_name = "AKSCustomMetricsMDM"
// 	  const      @@record_batch_size = 2600

// 	  const      @@tokenRefreshBackoffInterval = 30

// 	  const      @data_hash = {}
// 	  const      @parsed_token_uri = nil
// 	  const      @http_client = nil
// 	  const     @token_expiry_time = Time.now
// 	  const     @last_post_attempt_time = Time.now
// 	  const     @first_post_attempt_made = false
const CanSendDataToMdm = true

// 	  const      @last_telemetry_sent_time = nil
//       # Setting useMsi to false by default
const useMsi = false

// 	  const     @get_access_token_backoff_expiry = Time.now

// var (
// 	// ImageIDMap caches the container id to image mapping
// 	ImageIDMap map[string]string
// 	// NameIDMap caches the container it to Name mapping
// 	NameIDMap map[string]string
// 	// StdoutIgnoreNamespaceSet set of  excluded K8S namespaces for stdout logs
// 	StdoutIgnoreNsSet map[string]bool
// 	// StderrIgnoreNamespaceSet set of  excluded K8S namespaces for stderr logs
// 	StderrIgnoreNsSet map[string]bool
// 	// DataUpdateMutex read and write mutex access to the container id set
// 	DataUpdateMutex = &sync.Mutex{}
// 	// ContainerLogTelemetryMutex read and write mutex access to the Container Log Telemetry
// 	ContainerLogTelemetryMutex = &sync.Mutex{}
// 	// ClientSet for querying KubeAPIs
// 	ClientSet *kubernetes.Clientset
// 	// Config error hash
// 	ConfigErrorEvent map[string]KubeMonAgentEventTags
// 	// Prometheus scraping error hash
// 	PromScrapeErrorEvent map[string]KubeMonAgentEventTags
// 	// EventHashUpdateMutex read and write mutex access to the event hash
// 	EventHashUpdateMutex = &sync.Mutex{}
// )

var (
CachedAccessToken string
)

var (
	// FLBLogger stream
	FLBLogger = createLogger()
	// Log wrapper function
	Log = FLBLogger.Printf
)

func createLogger() *log.Logger {
	var logfile *os.File
	path := "/var/opt/microsoft/docker-cimprov/log/fluent-bit-out-oms-runtime.log"
	if _, err := os.Stat(path); err == nil {
		fmt.Printf("File Exists. Opening file in append mode...\n")
		logfile, err = os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0600)
		if err != nil {
			SendException(err.Error())
			fmt.Printf(err.Error())
		}
	}

	if _, err := os.Stat(path); os.IsNotExist(err) {
		fmt.Printf("File Doesnt Exist. Creating file...\n")
		logfile, err = os.Create(path)
		if err != nil {
			SendException(err.Error())
			fmt.Printf(err.Error())
		}
	}

	logger := log.New(logfile, "", 0)

	logger.SetOutput(&lumberjack.Logger{
		Filename:   path,
		MaxSize:    10, //megabytes
		MaxBackups: 1,
		MaxAge:     28,   //days
		Compress:   true, // false by default
	})

	logger.SetFlags(log.Ltime | log.Lshortfile | log.LstdFlags)
	return logger
}

// Method to get access token
func GetAccessToken() {

}


// InitializeMdmPlugin reads and populates plugin configuration
func InitializeMdmPlugin(pluginConfPath string, agentVersion string) {
	//Read azure json file to get the Service Principal value
	azureJSONFile, err := ioutil.ReadFile(AzureJsonPath)
	if err != nil {
		message := fmt.Sprintf("Error while reading azure json file", err.Error())
		Log(message)
		SendException(message)
		return output.FLB_OK
	}
	var result map[string]interface{}
	err := json.Unmarshal([]byte(ToString(azureJSONFile)), &result)

	if err != nil {
		message := fmt.Sprintf("Error while unmarshaling azure json file", err.Error())
		Log(message)
		SendException(message)
		return output.FLB_OK
	}

	aksResourceID := os.Getenv("AKS_RESOURCE_ID")
	aksRegion := os.Getenv("AKS_REGION")

	if aksResourceID == "" {
		message := fmt.Sprintf("Environment Variable AKS_RESOURCE_ID is not set.. ")
		Log(message)
		CanSendDataToMdm = false
	}
	end
	if aksRegion == "" {
		message := fmt.Sprintf("Environment Variable AKS_REGION is not set.. ")
		Log(message)
		CanSendDataToMdm = false
	} else {
		aksRegion = strings.Replace(aksRegion, " ", "", -1)
	}

	if CanSendDataToMdm {
	Log("MDM Metrics supported in", aksRegion, "region")

	postRequestUrl := strings.Replace(PostRequestUrlTemplate, "aks_region", aksRegion, -1)
	postRequestUrl = strings.Replace(PostRequestUrlTemplate, "aks_resource_id", aksResourceID, -1)

	// @post_request_uri = URI.parse(@@post_request_url)
	// @http_client = Net::HTTP.new(@post_request_uri.host, @post_request_uri.port)
	// @http_client.use_ssl = true
	// @log.info "POST Request url: #{@@post_request_url}"

	// Send telemetry to AppInsights resource
	SendEvent("AKSCustomMetricsMDMGoPluginStart", map[])

	// Check to see if SP exists, if it does use SP. Else, use msi
	spClientId := result["aadClientId"]
	spClientSecret := result["aadClientSecret"]

	if (spClientId != nil &&
		spClientId != "" && 
		strings.ToLower(spClientId) != "msi") {
	  useMsi = false
	//   aad_token_url = @@aad_token_url_template % {tenant_id: @data_hash["tenantId"]}
	  aadTokenUrl = strings.Replace(AadTokenUrlTemplate, "tenant_id", result["tenantId"], -1)
	//   @parsed_token_uri = URI.parse(aad_token_url)
	} else {
	  useMsi = true
	  msiEndpoint = strings.Replace(MsiEndpointTemplate, "user_assigned_client_id", UserAssignedClientId, -1)
	  msiEndpoint = strings.Replace(MsiEndpointTemplate, "token_resource_url", TokenResourceUrl , -1)
	//   @parsed_token_uri = URI.parse(msi_endpoint)
	}

	CachedAccessToken = GetAccessToken
	}
}
