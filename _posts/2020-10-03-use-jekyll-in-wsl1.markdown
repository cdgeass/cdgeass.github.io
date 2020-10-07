---
layout: post
title: "在wsl1中使用jekyll创建Github Pages"
tags: wsl jekyll
---

Github Pages官方推荐的是使用jekyll来创建博客。使用jekyll需要安装Ruby，而windows下使用Ruby不太方便所以使用wsl来安装Ruby。自己电脑的部分软件和Hyper-V冲突所以依然使用wsl1（更推荐wsl2）。  

1. 先创建一个Repo，以 **用户名.github.io** 做名称

2. 在wsl中安装jekyll  

    ```
    sudo apt-get update -y && sudo apt-get upgrade -y
    sudo apt-add-repository ppa:brightbox/ruby-ng
    sudo apt-get update
    sudo apt-get install ruby2.5 ruby2.5-dev build-essential dh-autoreconf

    gem update
    gem install jekyll bundler
    ```  

3. 新建一个本地Repo，并使用jekyll初始化  

    ```
    git init blog
    cd blog
    jekyll new .
    ```  

    修改Gemfile文件，将`gem "jekyll", "~> 4.1.1"`注释。 
    将其中的`gem "github-pages", group: :jekyll_plugins`取消注释并添加版本信息`gem "github-pages", "~> VERSION", group: :jekyll_plugins`。  
    对应的版本参照[Dependency Versions](https://pages.github.com/versions/)  

    执行`bundle update`，如果提示`nokogiri`安装错误执行以下命令，其中的目录名需要按照自己安装时的版本对应修改

    ```
    sudo apt install libxslt-dev build-essential ruby-dev zlib1g-dev liblzma-dev libxmlsec1-dev libxml2-dev
    sudo mkdir -p /var/lib/gems/2.5.0/extensions/x86_64-linux/2.5.0/nokogiri-1.10.10/nokogiri
    bundle config build.nokogiri --use-system-libraries
    ```  

    完成后使用`bundle exec jekyll serve`即可在本地预览博客页面

4. 添加Github Repo作为远程仓库即可  

如果使用Github Settings中的主题切换需要注意按照对应主题修改项目中index.markdown和about.mardown中的内容