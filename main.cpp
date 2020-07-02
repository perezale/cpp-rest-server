// (c) 2019 Nick Gerakines
// This code is licensed under MIT license#include <signal.h>
#include <thread>
#include <chrono>
#include "cpprest/http_listener.h"
#include <curl/curl.h> // has to go before opencv header
#include <opencv2/xfeatures2d.hpp>
#include <opencv2/features2d.hpp>
#include <opencv2/highgui.hpp>
#include "opencv2/imgcodecs.hpp"
#include <opencv2/opencv.hpp>
#include <opencv2/core/core.hpp>


using namespace cv;
using namespace cv::xfeatures2d;
using namespace std;
using namespace web;
using namespace http;
using namespace utility;
using namespace http::experimental::listener;

//curl writefunction to be passed as a parameter
// we can't ever expect to get the whole image in one piece,
// every router / hub is entitled to fragment it into parts
// (like 1-8k at a time),
// so insert the part at the end of our stream.
size_t write_data(char *ptr, size_t size, size_t nmemb, void *userdata)
{
    vector<uchar> *stream = (vector<uchar>*)userdata;
    size_t count = size * nmemb;
    stream->insert(stream->end(), ptr, ptr + count);
    return count;
}

//function to retrieve the image as cv::Mat data type
cv::Mat curlImg(const char *img_url, int timeout=10)
{
    vector<uchar> stream;
    CURL *curl = curl_easy_init();
    
    curl_easy_setopt(curl, CURLOPT_URL, img_url); //the img url
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data); // pass the writefunction
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &stream); // pass the stream ptr to the writefunction
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout); // timeout if curl_easy hangs,
    CURLcode res = curl_easy_perform(curl); // start curl
    curl_easy_cleanup(curl); // cleanup
    return imdecode(stream, -1); // 'keep-as-is'
    
}


class Server
{
public:
    Server() : m_listener(U("http://0.0.0.0:8080/"))
    {
        m_listener.support(methods::GET, bind(&Server::handle_get, this, placeholders::_1));
    }

    pplx::task<void> open() { return m_listener.open(); }
    pplx::task<void> close() { return m_listener.close(); }

private:

    void handle_get(http_request message)
    {
        // Decode uri (relative path)
        auto path = uri::decode(message.relative_uri().path());

        if (!path.empty() && path != U("/")) {
            message.reply(status_codes::BadRequest, U("Service available at /"));
            return;
        }
        // Split query
        auto query = uri::split_query(message.request_uri().query());
        // Find parameter "url"
        auto itUrl = query.find(U("url"));
        if(itUrl == query.end())
        {
            message.reply(status_codes::BadRequest, U("Service available at /"));
            return;
        }
        auto url = itUrl->second;
        //Mat src = imread(U("resources/testImage.png"), IMREAD_COLOR);
        Mat src = curlImg(url.c_str());
        if (src.empty()){
            cout<<"Error in image"<<endl;
            message.reply(status_codes::BadRequest, U("Error in image"));
            return;
        }        

        // Build output
        auto response = json::value::object();
        response["resolution"] = json::value::string( to_string(src.cols)+ "," + to_string(src.rows));
        response["http_method"] = json::value::string(methods::GET);
        response["url"] = json::value::string(url);
        // response = U("Hello world!");
        message.reply(status_codes::OK, response);
    }
    http_listener m_listener;
};

unique_ptr<Server> g_httpServer;void signalHandler(int signum)
{
    g_httpServer->close().wait();
    exit(signum);
}

int main()
{

    cout<<"CPPRest Service!"<<endl;
    g_httpServer = unique_ptr<Server>(new Server());
    g_httpServer->open().wait();    signal(SIGINT, signalHandler);
    signal(SIGTERM, signalHandler);    while (1)
    {
        this_thread::sleep_for(chrono::seconds(1));
    }    return 0;
}
