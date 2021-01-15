---
layout: post
title: "SpringMVC获取HttpServletRequest的三种方式"
tags: spring spring-mvc spring-boot
---

使用SpringMVC的时候一般可以使用 @RequestBody、@RequestParam 来获取参数，但是有时候也会有些需求导致我们需要拿到 HttpServletRequeset。  

平时开发中我常用的有三种方法  

1. Controller 参数  
<br>
![参数](https://raw.githubusercontent.com/cdgeass/pictures/main/2021-01-14-three-method-to-get-http-servlet-request-parameter.png)  
<br>
通常比较常用的应该是这种方式，使用起来比较方便，代码侵入性个人觉得也低些。那么这里的 HttpServletRequest 如何获取的呢？通过调试我们可以定位到在 InvcoableHandlerMethod 中的invokeForRequest 方法中根据接口方法的定义来生成参数进行调用，在 getMethodArgumentValues 中通过调用各种 resolver 来进行参数处理。针对 HttpServletRequest 使用的是 SerlvetRequestMethodArgumentResolver。具体实现暂不进行深究。
<br>  
![InvocableHandlerMethod](https://raw.githubusercontent.com/cdgeass/pictures/main/2021-01-14-three-method-to-get-http-servlet-request-InvocableHandlerMethod.png)  
<br>  

2. 依赖注入  
<br>
![依赖注入](https://raw.githubusercontent.com/cdgeass/pictures/main/2021-01-14-three-method-to-get-http-servlet-request-injection.png)  
<br>
虽然可以通过参数的方式直接获取 HttpServletRequest，但是如果我们的 Service 中也需要使用到的话就需要逐级传递 HttpSerlvetRequest 比较麻烦。我们也可以直接在 Controller 中注入 HttpServletRequest的Bean 。但是就有问题了， Controller 是单例的，而我们每次进行请求的 Request 肯定是不一样的，那么这里注入的是什么呢？  
<br>
我们打一个断点就能看到这里的注入的是一个代理对象其实现类是 ObjectFactoryDelegatingInvocationHandler，那它代理的是 HttpServletRequest 吗？也不是，它代理的是 RequestObjectFactory ，实现了了 ObjectFactory\<ServletRequest\>。  
<br>
![RequestObjectFactory](https://raw.githubusercontent.com/cdgeass/pictures/main/2021-01-14-three-method-to-get-http-servlet-request-RequestObjectFactory.png)
![ObjectFactory](https://raw.githubusercontent.com/cdgeass/pictures/main/2021-01-14-three-to-get-http-servlet-request-ObjectFactory.png)  
<br>
根据注释描述来看这个接口的定义和 FactoryBean 相似，都提供了获取 Bean 的接口。区别在于 FactoryBean 通常是作为 SPI 的实例，而 ObjectFactory 的实现是通过被注入后调用 API 获取。这里使用的 RequestObjectFactory 就是通过 RequestContextHolder 获取 HttpServletRequest。  

3. 通过 Holder 获取  
<br>
![RequestContextHolder](https://raw.githubusercontent.com/cdgeass/pictures/main/2021-01-14-three-method-to-get-http-servlet-request-holder.png)  
<br>
也可以通过 RequestContextHolder 来获取 RequestAttributes，强转成 ServletRequestAttributes 再获取 HttpservletRequest。这样也能够获取 HttpServletRequest 只是自己需要进行处理，可以对 RequestContextHolder 再进行一次封装来方便调用，RequstObjectFactory 其实也是这样做的。
