# encoding: utf-8
class UserpicLoader
    def self.cache_path
        @cache_path ||= File.join(Feed.result_path, 'userpics').tap{|p| FileUtils.mkdir_p p}
    end
    
    def initialize(feed)
        @feed = feed
    end

    attr_reader :feed
    
    def run(user, key)
        @user, @key = user, key
        load_users!
        extract_userpics
    end

    private

    def load_users!
        log.info "Загружаем имена пользователей"
        @users = []

        Dir[feed.json_path('entries/*.js')].each_with_progress do |f|
            e = feed.load_mash(f)
            uids = [e, *e.likes, *e.comments].map(&:from).map(&:id)
            @users.push(*uids)
        end
        @users = @users.uniq.sort
        log.info "Загружено #{@users.count} пользователей"
    end

    def extract_userpics
        to_extract = @users.reject{|u| File.exists?(userpic_path(u))}
        if to_extract.empty?
            log.info "Все нужные юзерпики закешированы"
        else
            log.info "Не закешировано: #{to_extract.count} юзерпиков, загружаем"
            to_extract.each_with_progress do |u|
                extract_userpic(u)
            end
        end
    end

    def cache_path
        self.class.cache_path
    end

    def log
        Clio.log
    end

    def userpic_path(user)
        File.join(cache_path, "#{user}.jpg")
    end

    def extract_userpic(user, size='large')
        img = raw_request("picture/#{user}", 'size' => size)
        File.write userpic_path(user), img
    end

    def raw_request(method, params = {})
        http = SimpleHttp.new construct_url(method, params)
        http.basic_authentication @user, @key
        
        # somehow internal SimpleHttp's redirection following fails
        http.register_response_handler(Net::HTTPRedirection){|request, response, shttp| 
            SimpleHttp.get response['location'] 
        }
        http.get
    end

    def construct_url(method, params)
        "http://friendfeed-api.com/v2/#{method}?" + params.map{|k, v| "#{k}=#{v}"}.join('&')
    end
end
