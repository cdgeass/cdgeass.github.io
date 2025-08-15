---
title: Java 偏向锁
date: 2025-08-01 15:59:18
categories: 
tags:
  - Java
---
偏向锁于 JDK1.6 引入，JDK15 中已被废弃，可以通过参数 `-XX:+UseBiasedLocking` 启用。

早期线程安全的集合如 HashTable，Vector 等都依赖于 synchronized，而大多数情况下不存在线程竞争，使用偏向锁可以减少这种情况下的同步开销，偏向锁会偏向于第一个获取它的线程。

当有其他线程尝试获取锁时偏向锁会进行撤销操作。撤销操作需要等待全局安全点，暂停持有锁的线程并检查是否在执行同步块中的代码，如果是则升级为轻量锁，否则其他线程可以竞争该锁。所以高并发的场景偏向锁会导致STW时间过长，于是在 JDK15 中被弃用。

### 对象头

64位虚拟机为例，偏向锁的Mark Word结构如下。

| 54bit  | 2bit  | 1bit | 4bit | 1bit   | 2bit |
| ------ | ----- | ---- | ---- | ------ | ---- |
| 偏向线程ID | Epoch |      | 年龄   | 偏向锁标志位 | 01   |

### 偏向锁延迟

由于 JVM 内部大量使用 synchronized 来保证线程安全而之前说过频繁的偏向锁撤销会带来额外的开销，所以 JVM 在启动后会延迟一段时间（默认为4秒）才启用偏向锁。

我们使用 jol 来打印对象头的信息，以观察偏向锁的状态。

```xml
<dependency>
    <groupId>org.openjdk.jol</groupId>
    <artifactId>jol-core</artifactId>
    <version>0.17</version>
</dependency>
```

新生成的对象处于无锁不偏向的状态，此时获取到的锁为轻量级锁。
延迟5秒以确保偏向锁已启用。此时新生成的对象为匿名偏向状态，偏向锁标志位为1，但存储的线程id为空。
在获取锁后偏向锁偏向当前线程。

```java
/**
 * 添加 jvm 参数确保启用偏向锁以及延迟4000毫秒启动 -XX:+UseBiasedLocking -XX:BiasedLockingStartupDelay=4000
 */
public static void biasedLock() {
    Object lock = new Object();
    System.out.println("无锁不可偏向");
    System.out.println(ClassLayout.parseInstance(lock).toPrintable());

    synchronized (lock) {
        System.out.println("轻量级锁");
        System.out.println(ClassLayout.parseInstance(lock).toPrintable());
    }

    try {
        Thread.sleep(5000);
    } catch (InterruptedException e) {
        e.printStackTrace();
    }

    lock = new Object();
    System.out.println("匿名偏向");
    System.out.println(ClassLayout.parseInstance(lock).toPrintable());

    synchronized (lock) { }
	
    System.out.println("偏向当前线程");
    System.out.println(ClassLayout.parseInstance(lock).toPrintable());
}
```

### 批量重偏向

```java
public class BiasedLockingDemo {  
  
    public static class Lock {  
    }  
    public static void main(String[] args) throws InterruptedException {  
// 等待偏向锁激活  
        Thread.sleep(5000);  
  
        List<Lock> locks = new ArrayList<>();  
        int lockCount = 30;  
  
        // 线程t1使所有锁偏向它  
        Thread t1 = new Thread(() -> {  
            for (int i = 0; i < lockCount; i++) {  
                Lock lock = new Lock();  
                locks.add(lock);  
                synchronized (lock) {}  
            }        }, "t1");  
        t1.start();  
        t1.join();  
  
        System.out.println("--- 初始状态：所有锁都偏向 t1 ---");  
        System.out.println(ClassLayout.parseInstance(locks.get(0)).toPrintable());  
  
        // 线程t2获取锁  
        Thread t2 = new Thread(() -> {  
            // 1. 获取第0个锁，这将触发标准的偏向锁撤销  
            synchronized (locks.get(0)) {  
                // ... do nothing  
            }  
  
            // 2. 循环获取锁，以触发批量重偏向  
            // 注意：循环从1开始，因为第0个锁已经用过了  
            for (int i = 1; i < lockCount; i++) {  
                synchronized (locks.get(i)) {  
                    // ... do nothing  
                }  
            }        }, "t2");  
        t2.start();  
        t2.join();  
  
        System.out.println("\n--- 锁释放后 ---");  
  
        System.out.println(">>> Lock #0 (标准撤销后) 的状态：应为无锁不可偏向 <<<");  
        // 该锁经历了标准撤销，释放后应变为无锁状态  
        System.out.println(ClassLayout.parseInstance(locks.get(0)).toPrintable());  
  
        System.out.println("\n>>> Lock #25 (批量重偏向后) 的状态：应仍然偏向 t2 <<<");  
        // 该锁在批量重偏向机制激活后被t2获取，释放后应保持对t2的偏向  
        System.out.println(ClassLayout.parseInstance(locks.get(25)).toPrintable());  
    }}
```


