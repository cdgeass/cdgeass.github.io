---
layout: post
title: Spring 循环依赖
tags: spring
---

1. 什么是循环依赖

   <div class="mermaid">
   graph LR;
       A[bean A] ---> B[bean B];
       A[bean A] <--- B[bean B];
   </div>

   bean A 里依赖了 bean B，同时 bean B 里也依赖了 bean B。

2. Spring 无法解决循环依赖的场景

   Spring 里 bean 注入通常使用构造器注入或者 field 注入。

   当使用构造器注入的时候 Spring 无法解决循环依赖会在启动时直接报错，因为在解决循环依赖时 Spring 会在实例化 bean 然后再解决依赖关系，使用构造器注入需要直接使用 bean 进行实例化。

   ```java
   @Component
   public class A {

    private final B b;

    public A(B b) {
        this.b = b;
    }
   }

   @Component
   public class B {

    private final A a;

    public B(A a) {
        this.a = a;
    }
   }

   public static void main(String[] args) {
    AnnotationConfigApplicationContext applicationContext = new AnnotationConfigApplicationContext();

    // constructor circular dependency
    applicationContext.register(A.class, B.class);

    applicationContext.refresh();
    System.out.println("applicationContext refreshed");

    applicationContext.close();
   }
   ```

   ```java
   Exception encountered during context initialization - cancelling refresh attempt: org.springframework.beans.factory.UnsatisfiedDependencyException: Error creating bean with name 'a': Unsatisfied dependency expressed through constructor parameter 0; nested exception is org.springframework.beans.factory.UnsatisfiedDependencyException: Error creating bean with name 'b': Unsatisfied dependency expressed through constructor parameter 0; nested exception is org.springframework.beans.factory.BeanCurrentlyInCreationException: Error creating bean with name 'a': Requested bean is currently in creation: Is there an unresolvable circular reference?
   ```

   当循环依赖的 bean 的 scope 都是 prototype 时，尝试解决 A 对 B 的依赖时 B 里注入的 A 就不是实例化完成的 A 而是新创建的 A，陷入死循环。  
   `如果 A 和 B 设置了 proxyMode=TARGET_CLASS/INTERFACES 那么就不会报错。因为此时注入的是 A 和 B 的单例的代理类。`

   ```java
   @Component
   @Scope(ConfigurableBeanFactory.SCOPE_PROTOTYPE)
   public class A {

    @Autowired
    private B b;
   }

   @Component
   @Scope(ConfigurableBeanFactory.SCOPE_PROTOTYPE)
   public class B {

    @Autowired
    private A a;
   }

   public static void main(String[] args) {
    AnnotationConfigApplicationContext applicationContext = new AnnotationConfigApplicationContext();

    // prototype circular dependency
    applicationContext.register(A.class, B.class);

    applicationContext.refresh();
    System.out.println("applicationContext refreshed");

    applicationContext.getBean(A.class);

    applicationContext.close();
   }
   ```

   ```java
   Exception in thread "main" org.springframework.beans.factory.UnsatisfiedDependencyException: Error creating bean with name 'A': Unsatisfied dependency expressed through field 'b'; nested exception is org.springframework.beans.factory.UnsatisfiedDependencyException: Error creating bean with name 'B': Unsatisfied dependency expressed through field 'a'; nested exception is org.springframework.beans.factory.BeanCurrentlyInCreationException: Error creating bean with name 'A': Requested bean is currently in creation: Is there an unresolvable circular reference?
   ```

3. 如何解决

   Spring 使用了三级缓存解决循环依赖的问题。

   Spring 在 DefaultSingletonBeanRegistry 中定义了三级缓存：

   > 1. singleObjects 一级缓存缓存；已经初始化完成的 bean
   > 2. earlySingletonObjects 二级缓存；bean 从三级缓存中获取后放进二级缓存并从三级缓存中移出
   > 3. singletonFactories 三级缓存；缓存创建 bean 的工厂，创建完成后就会从三级缓存移入二级缓存

   主要逻辑在 AbstractAutowireCapableBeanFactory#doCreateBean 中

   ```java
   protected Object doCreateBean(String beanName, RootBeanDefinition mbd, @Nullable Object[] args)
     throws BeanCreationException {

    ...
    if (instanceWrapper == null) {
     // 实例化 bean
     instanceWrapper = createBeanInstance(beanName, mbd, args);
    }

    ...
    boolean earlySingletonExposure = (mbd.isSingleton() && this.allowCircularReferences &&
      isSingletonCurrentlyInCreation(beanName));
    if (earlySingletonExposure) {
     ...
     // 将实例化的 bean 放入三级缓存
     addSingletonFactory(beanName, () -> getEarlyBeanReference(beanName, mbd, bean));
    }

    Object exposedObject = bean;
    try {
     // 根据 beanDefinition 填充 bean，依赖注入
     populateBean(beanName, mbd, instanceWrapper);
     // 初始化 bean
     exposedObject = initializeBean(beanName, exposedObject, mbd);
    }
    ...
   }
   ```

   这里有三个关键方法：

   - createBeanInstance()

     实例化 bean；如果该 bean 是单例的且允许循环依赖并且 bean 在创建中那么将实例化完成的 bean 放入三级缓存中。

   - populateBean()

     填充 bean，进行依赖注入。查找需要注入的 bean，如果不存在则进行创建。

   - initializeBean()

     对 bean 进行初始化

   <div class="mermaid">
   sequenceDiagram
        participant createBeanInstance()
        participant singletonFactories
        participant populateBean()
        participant initializeBean()
        createBeanInstance()->>singletonFactories: 实例化 A，放入三级缓存
        singletonFactories->>populateBean(): 填充 A
        populateBean()->>createBeanInstance(): 注入 B，B 不存在，进行创建
        createBeanInstance()-->>singletonFactories: 实例化 B, 放入三级缓存
        singletonFactories-->>populateBean(): 填充 B
        populateBean()-->>singletonFactories: 查找 A
        singletonFactories-->>populateBean(): 移出 A 放入二级缓存，A 注入 B
        populateBean()-->>initializeBean(): 初始化 B
        initializeBean()->>populateBean(): B 注入 A
        populateBean()->>initializeBean(): 初始化 A
   </div>

4. 为什么需要三级缓存？

在 AbstractAutowireCapableBeanFactory#doCreateBean 中放入三级缓存的是 getEarylyBeanReference 方法，这里调用了 SmartInstantiationAwareBeanPostProcessor#getEarlyBeanReference 方法，默认实现是直接返回当前 bean。

```java
// AbstractAutowireCapableBeanFactory#doCreateBean
protected Object getEarlyBeanReference(String beanName, RootBeanDefinition mbd, Object bean) {
 Object exposedObject = bean;
 if (!mbd.isSynthetic() && hasInstantiationAwareBeanPostProcessors()) {
  for (BeanPostProcessor bp : getBeanPostProcessors()) {
   if (bp instanceof SmartInstantiationAwareBeanPostProcessor) {
    SmartInstantiationAwareBeanPostProcessor ibp = (SmartInstantiationAwareBeanPostProcessor) bp;
    exposedObject = ibp.getEarlyBeanReference(exposedObject, beanName);
   }
  }
 }
 return exposedObject;
}

// SmartInstantiationAwareBeanPostProcessor#getEarlyBeanReference
default Object getEarlyBeanReference(Object bean, String beanName) throws BeansException {
 return bean;
}
```

而在 AOP 的场景下，代理对象是在 initializeBean 中创建的，注册进 Spring 容器的应该是代理对象而不是原对象，那么就不得不提前将代理对象提供给被注入的 bean。

```java
// AbstractAutowireCapableBeanFactory#initializeBean
protected Object initializeBean(String beanName, Object bean, @Nullable RootBeanDefinition mbd) {
 if (System.getSecurityManager() != null) {
  AccessController.doPrivileged((PrivilegedAction<Object>) () -> {
   invokeAwareMethods(beanName, bean);
   return null;
  }, getAccessControlContext());
 }
 else {
  invokeAwareMethods(beanName, bean);
 }

 Object wrappedBean = bean;
 if (mbd == null || !mbd.isSynthetic()) {
  // 调用 BeanProcessor#postProcessBeforeInitialization
  // 这里是一个赋值语句 原来的 bean 可能会被替换成代理类。但实际实现类上大多是进行一些前置处理没有真正改变当前 bean
  wrappedBean = applyBeanPostProcessorsBeforeInitialization(wrappedBean, beanName);
 }

 try {
  invokeInitMethods(beanName, wrappedBean, mbd);
 }
 catch (Throwable ex) {
  throw new BeanCreationException(
    (mbd != null ? mbd.getResourceDescription() : null),
    beanName, "Invocation of init method failed", ex);
 }
 if (mbd == null || !mbd.isSynthetic()) {
  // 调用 BeanProcessor#postProcessorsAfterInitialization
  // 这里是一个赋值语句 原来的 bean 可能会被替换成代理类
  wrappedBean = applyBeanPostProcessorsAfterInitialization(wrappedBean, beanName);
 }

 return wrappedBean;
}
```

BeanProcessor 的其中一个实现类 AbstractAutoProxyCreator，在调用 getEarlyBeanReference 时会生成包裹的代理类，当真正调用 postProcessAfterInitialization 时因为已经提前生成过代理类并放入了二级缓存中，就不再重复生成。

```java
public abstract class AbstractAutoProxyCreator extends ProxyProcessorSupport implements SmartInstantiationAwareBeanPostProcessor, BeanFactoryAware {
 @Override
 public Object getEarlyBeanReference(Object bean, String beanName) {
  // 提前提供代理对象
  Object cacheKey = getCacheKey(bean.getClass(), beanName);
  this.earlyProxyReferences.put(cacheKey, bean);
  return wrapIfNecessary(bean, beanName, cacheKey);
 }

 @Override
 public Object postProcessAfterInitialization(@Nullable Object bean, String beanName) {
  if (bean != null) {
   Object cacheKey = getCacheKey(bean.getClass(), beanName);
   // 代理对象已经创建过了，不再重复创建
   if (this.earlyProxyReferences.remove(cacheKey) != bean) {
    return wrapIfNecessary(bean, beanName, cacheKey);
   }
  }
  return bean;
 }
}

// AbstractAutowireCapableBeanFactory#doCreateBean
protected Object doCreateBean(String beanName, RootBeanDefinition mbd, @Nullable Object[] args) throws BeanCreationException {
  ...
  Object exposedObject = bean;
  try {
   populateBean(beanName, mbd, instanceWrapper);
   // 使用 BeanPostProcessor 处理，有可能返回代理对象
   exposedObject = initializeBean(beanName, exposedObject, mbd);
  }
  catch (Throwable ex) {
   if (ex instanceof BeanCreationException && beanName.equals(((BeanCreationException) ex).getBeanName())) {
    throw (BeanCreationException) ex;
   }
   else {
    throw new BeanCreationException(
      mbd.getResourceDescription(), beanName, "Initialization of bean failed", ex);
   }
  }

  if (earlySingletonExposure) {
   // 如果是被提前注入的 bean 去缓存中查找
   Object earlySingletonReference = getSingleton(beanName, false);
   if (earlySingletonReference != null) {
    // 如果 initializeBean 阶段没有被再次修改则用代理对象替换当前 bean 
    if (exposedObject == bean) {
     exposedObject = earlySingletonReference;
    }
    else if (!this.allowRawInjectionDespiteWrapping && hasDependentBean(beanName)) {
     // 当前 bean 修改了进行异常处理
     String[] dependentBeans = getDependentBeans(beanName);
     Set<String> actualDependentBeans = new LinkedHashSet<>(dependentBeans.length);
     for (String dependentBean : dependentBeans) {
      if (!removeSingletonIfCreatedForTypeCheckOnly(dependentBean)) {
       actualDependentBeans.add(dependentBean);
      }
     }
     if (!actualDependentBeans.isEmpty()) {
      ...
      // 错误信息
     }
    }
   }
  }
}
```

> 这里其实直接调用 getEarlyBeanReference 并放入二级缓存中应该不会影响整体流程，如果多个 bean 循环依赖除了第一个 bean 其他的也都是从二级缓存中获取的 bean。三次缓存的设计应该是保证没有循环依赖时遵循 bean 的生命周期，在 initializeBean 阶段生成代理对象，而出现循环依赖的情况下只能提前生成代理对象。
