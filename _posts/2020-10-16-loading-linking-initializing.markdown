---
layout: post
title: "Java类加载过程"
tag: java jvm 类加载
---
Java的类加载过程可以分成三步主要步骤：  

{% mermaid %}
graph LR;
    A[加载]-->B{连接}-->C[初始化];
{% endmermaid %}  

其中`连接`又可以分成三步：  

{% mermaid %}
graph LR;
    A[加载]-->B[验证]-->C[准备]-->D[解析]-->E[初始化];
{% endmermaid %}  

其中的加载，验证，准备，初始化需要保证相对顺序。而解析步骤可以放在初始化后进行（为了支持动态绑定）。而加载步骤可以随时进行。  

## 加载  

加载阶段需要完成三件事：  

1. 通过类的全限定名获取定义此类的二进制流  
2. 将字节流代表的静态存储结构转换成方法区的运行时数据结构  
3. 在堆内存中生成类的java.lang.Class对象，作为方法区这个类的公共数据的入口  

数组类型由Java虚拟机直接在内存中创建。其中引用类型的数组会对组件类型进行递归加载，并将数组分配到组件类型对应的类加载器的命名空间上；原始类型则没有类加载器。  

需要注意的是当调用数组类型的getClassLoader()时有两种情况：  

```java
new String[]{}.getClass().getClassLoader();
new int[]{}.getClass().getClassLoader();
```

上面两条语句都返回null，String数组返回null因为String属于java.lang，属于启动类加载器，调用getClassLoader()时返回null；而int数组返回null因为int属于原始类型，没有对应的类加载器。  

## 验证  

验证阶段包含四个阶段：  

1. 文件格式验证  
2. 元数据验证  
3. 字节码验证  
4. 符号引用验证  

字节流通过文件格式验证之后会被解析并储存在方法区中，后续的三步验证都基于方法区进行不需要再操作字节流。  

## 准备  

准备阶段会为static变量赋零值（非代码中定义的初始值），常量在编译期就被放进了常量池中所以这里直接赋初始值。  

## 解析  

解析是Java虚拟机将常量池内的符号引用替换为直接引用的过程。解析可以发生在类被加载时，也可以发生在符号引用被使用前，由虚拟机自行判断。  

除了invokedynamic指令外，虚拟机可以对第一次解析的结果进行缓存。如果在同一个实体中符号引用被解析成功过，那么后续的解析就应当一直成功；如果第一次解析失败了，那么即使后续能够成功解析仍应返回相同的异常。  

解析分为四种情况：  

1. 类或接口的解析  
在D中对C进行引用  
    * 如果C不是数组类型，将C交给D的类加载器进行加载。加载过程中出现失败则解析过程失败
    * 如果C是数组类型，且C的组件类型是引用类型，则对组件类型递归进行解析操作
    * 如果没有发生异常则校验D对C的访问权限，无权限情况下抛出java.lang.IllegalAccessError
2. 字段解析  
解析字段所属的类或接口用C表示，然后在C中对字段进行搜索  
    * 如果C本身包含字段则返回字段的直接引用
    * 如果C实现了接口，按照继承关系从下往上查找接口和它的父接口，找到后返回字段的直接引用
    * 如果C不是java.lang.Object的话，按照继承关系从下往上查找其父类，找到后返回字段的直接引用
    * 如果没有找到，抛出java.lang.NoSuchFieldError
3. 方法解析
解析方法所属的类用C表示，然后在C中对方法进行搜索
    * 如果C是接口，抛出java.lang.IncompatibleClassChangeError
    * 如果方法在C中是一个[signature polymorphic method](https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-2.html#jvms-2.9)，则描述符中的所有类都会被解析
    * 如果C声明了方法则查找成功
    * 如果C有父类，在父类中递归查找
    * 如果在C的[maximally-specific superinterface method](https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-5.html#jvms-5.4.3.3)中只有一个方法匹配，并且不是抽象方法则查找成功
    * 如果在C实现的接口及父接口中有方法匹配且不是private, static的，任选其一
查找失败，抛出java.lang.NoSuchMethodError
4. 接口方法解析
解析方法所属的接口用C表示，然后在C中对方法进行搜索
    * 如果C是类，抛出java.lang.IncompatibleClassChangeError
    * 如果C中声明了方法则查找成功
    * 如果java.lang.Object中声明了方法且是public不是static的则查找成功
    * 如果C的maximally-specific superinterface method中只有一个方法匹配，并且不是抽象方法则查找成功
    * 如果C的父接口中有方法匹配并且不是private, static的，任选其一
    * 查找失败抛出java.lang.NoSuchMethodError  

## 初始化  

初始化阶段就是执行`<clinit>()`方法的阶段，`<clinit>()`由编译器收集类中所有的类变量以及静态语句块合并产生。编译器收集的顺序是由语句在源文件中出现的顺序决定的，静态语句块对在其之后定义的变量只能进行赋值操作而不能进行访问。  

Java虚拟机会保证父类的`<clinit>()`方法在子类之前执行。所以java.lang.Object的`<clinit>()`会在虚拟机中第一个执行，而父类的静态语句块也会优先于子类。如果一个类中没有静态语句块，也没有类变量，那么虚拟机可以不为该类生成`<clinit>()`方法。  

虽然接口中没有静态语句块，但是可以初始化变量，所以接口也会生成`<clinit>()`方法。接口的`<clinit>()`执行不需要先执行父接口的`<clinit>()`，只有在调用父接口的变量时才需要进行父接口的初始化。  

当有多个线程对类进行初始化操作时，只有一个线程能够执行`<clinit>()`，其他线程需要阻塞等待。当`<clinit>()`执行完成后，其他线程不需要再次执行，所以一个类加载器中一个类型只会被初始化一次。  