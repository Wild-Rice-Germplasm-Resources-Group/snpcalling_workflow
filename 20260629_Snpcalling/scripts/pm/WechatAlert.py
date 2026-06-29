import requests
import json
import time
import socket


class WechatAlert():
    def __init__(self, corpid="wwd83ce623cd077d1d", corpsecret="5SetDmLzZsGQlXHGRxkHAiqRIU1U1oMBK5jY541h0mQ"):
        self.url_gettoken = 'https://qyapi.weixin.qq.com/cgi-bin/gettoken'
        self.url_msg = 'https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token='
        self.corpid = corpid
        self.corpsecret = corpsecret
        self.expires_time = -1
        self.token = ''

    def get_token(self):
        if self.expires_time == -1 or self.expires_time-60 < time.time():
            self.get_token_request()
            return self.token
        else:
            return self.token

    def get_token_request(self):
        url_gettoken = self.url_gettoken
        values = {'corpid': self.corpid,
                  'corpsecret': self.corpsecret,
                  }
        req = requests.get(url_gettoken, params=values)
        if req.status_code != 200:
            print("Error get_token! req.status_code != 200")
            return -1
        data = json.loads(req.text)
        self.token = data["access_token"]
        self.expires_time = data["expires_in"] + time.time()

    def send_msg(self, values):
        url = self.url_msg + self.get_token()
        values = {#"touser": "@all",
                  "touser": "ZhengZeYu",
                  "toparty": "ZZ",
                  "totag": "",
                  "msgtype": "text",
                  "agentid": "1000002",
                  "text": {
                      "content": values
                  },
                  "safe": "0"
                  }
        a = requests.post(url, json=values)
        if a.status_code != 200:
            print("Error send msg! req.status_code != 200")
            return -1
        data = json.loads(a.text)
        if(data["errcode"]!=0):
            print("Error send msg! req errcode != 0 : {}")
            print(data)
            return(-1)
        #print(data)


if __name__ == '__main__':
    import sys
    zzalert = WechatAlert()
    zzstr=''
    for line in sys.stdin:
        zzstr = zzstr + line
        if len(zzstr)>300:
            print('msg Too long!')
            exit(-1)
    zzalert.send_msg(zzstr)

