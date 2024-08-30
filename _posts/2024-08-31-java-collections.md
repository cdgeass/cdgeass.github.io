---
layout: post
title: "Java 集合"
date: 2024-08-31 00:15:00 +0800
categories: java
---

## 实现

|Interface|Hash Table|Resizable Array|Balanced Tree|Linked List|Hash Table + Linked List|
|---------|-----------|---------------|--------------|-----------|-------------------------|
|Set        |HashSet    |                       |TreeSet          |                 |LinkedHashSet               |
|List       |                 |ArrayList         |                     |LinkedList  |                                     |
|Deque  |                 |ArrayDeque    |                      |LinkedList  |                                     |        
|Map     |HashMap  |                       |TreeMap        |                 |LinkedHashMap            |

## 并发实现

* BlockingQueue
* TransferQueue
* BlockingDeque
* ConcurrentMap
* ConcurrentNavigableMap

## List

### ArrayList

ArrayList内部使用数组来保存元素，并实现了RandomAccess接口提供了随机访问的能力

#### ArrayList 提供了3种构造方法。

* 使用初始容量构造
* 默认构造方法
* 使用Collection构造

初始容量为0或使用空集合进行构造时内部数组设为EMPTY_ELEMENTDATA常量，使用默认构造方法时内部数组设为DEFAULTCAPACITY_EMPTY_ELEMENTDATA常量，两个均为空数组用于在后续扩容时进行区分。  

EMPTY_ELEMENTDATA按当前容量为0进行扩容，DEFAULTCAPACITY_EMPTY_ELEMENTDATA按默认容量（10）进行扩容。

由上可知当List使用除Collection参数构造以外的方法构造时，在第一次插入数据时才进行真正的初始化并扩容。

#### 扩容时机

当List中插入元素后大小将大于内部数组长度时进行扩容。

扩容大小为原来1.5倍，若仍小于插入后大小则取扩容至插入后大小。扩容的最大大小为Integer.MAX_VALUE，但是会优先选择Integer.MAX_VALUE - 8，因为部分VM实现会在数组的头部插入些数据，这时扩容至Integer.MAX_VALUE会抛出OutOfMemoryError。

#### 迭代器

ArrayList可以返回Iterator和ListIterator后者支持向前遍历以及add操作。

ArrayList是非同步的，其迭代器使用了快速失败的方式，ArrayList内部使用了一个modCount变量记录了被修改的次数，当迭代器发现ArrayList被修改后则抛出异常以防止预期之外的异常发生。

### LinkedList

LinkedList使用了一个双向链表来保存元素，所以其同时还实现了Deque接口，相比于ArrayList其不支持使用index进行随机访问。相比ArrayList每个节点需要额外空间存储前后节点，但是不需要连续的内存空间。

使用双向链表的优点:

1. 当使用下标查询元素时会根据下标更接近头还是尾来决定是从头节点还是从尾节点开始查询。
2. 插入或删除时无需从头遍历来获取当前节点的前一个节点。  

## Set

### HashSet

HashSet使用了HashMap来实现，HashSet内元素作为内部HashMap的key来保证唯一。

### TreeSet

TreeSet使用了TreeMap来实现，并可以通过构造方法提供的Comparator来维元素排序。

### LinkedHashSet

LinkedHashASet使用了LinkedHashMap来实现，其中元素顺序依照插入顺序，相同元素的重新插入不影响其顺序。

## Map

### HashMap

HashMap由数组+链表+红黑树实现，创建HashMap时可指定initialCapacity以及loadFactor，前者为哈希表的初始大小后者为扩容因子，initialCapacity*loadFactor为扩容阈值。initalCapacity默认值为16，loadFactor默认值为0.75。哈希表的大小为2的次方，输入的initialCapacity会最接近的2的次方值作为实际大小。

HashMap在计算key的hash时会使用key的hashCode的高16位与hashCode进行异或操作，提高hash的随机性和均匀性。  

```java
static final int hash(Object key) {
    int h;
    return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
}
```

#### 扩容机制

当HashMap创建时内部的哈希表不会被初始化，当插入一个键值对时才会进行初始化即扩容。

每次扩容为上次容量的一倍。由于哈希表得容量为2的次方，扩容一倍可以保持其二进制值只有最高位为1，当扩容对其中元素重新计算其在哈希表中下标时更加高效，能够减少哈希冲突。

当插入元素后如果链表深度>8则会尝试将链表转换为红黑树，如果哈希表的容量小于64则不进行转换而是进行扩容。  

```java
final Node<K,V>[] resize() {
    Node<K,V>[] oldTab = table;
    int oldCap = (oldTab == null) ? 0 : oldTab.length;
    int oldThr = threshold;
    int newCap, newThr = 0;
    if (oldCap > 0) {
        if (oldCap >= MAXIMUM_CAPACITY) {
            threshold = Integer.MAX_VALUE;
            return oldTab;
        }
        else if ((newCap = oldCap << 1) < MAXIMUM_CAPACITY &&
                 oldCap >= DEFAULT_INITIAL_CAPACITY)
            newThr = oldThr << 1; // 扩容一倍后扩容阈值也翻倍
    }
    else if (oldThr > 0) // 构造函数中传入的initialCapacity计算其最近的二次幂后存储在threshold中，所以使用oldThr作为初始容量 
        newCap = oldThr;
    else {               // 默认构造方法
        newCap = DEFAULT_INITIAL_CAPACITY;
        newThr = (int)(DEFAULT_LOAD_FACTOR * DEFAULT_INITIAL_CAPACITY);
    }
    if (newThr == 0) { // 构造函数中传入initialCapacity的情况计算扩容阈值
        float ft = (float)newCap * loadFactor;
        newThr = (newCap < MAXIMUM_CAPACITY && ft < (float)MAXIMUM_CAPACITY ?
                  (int)ft : Integer.MAX_VALUE);
    }
    threshold = newThr;
    @SuppressWarnings({"rawtypes","unchecked"})
    Node<K,V>[] newTab = (Node<K,V>[])new Node[newCap];
    table = newTab;
    if (oldTab != null) {
        for (int j = 0; j < oldCap; ++j) {
            Node<K,V> e;
            if ((e = oldTab[j]) != null) {
                oldTab[j] = null;
                if (e.next == null)
                    newTab[e.hash & (newCap - 1)] = e; // 链表中仅有一个元素的情况直接计算新的下标
                else if (e instanceof TreeNode)
                    ((TreeNode<K,V>)e).split(this, newTab, j, oldCap); // 红黑树的场合
                else { // preserve order
                    Node<K,V> loHead = null, loTail = null;
                    Node<K,V> hiHead = null, hiTail = null;
                    Node<K,V> next;
                    do {
                        next = e.next;
                        // oldCap为2的次方仅最高位为1，通过&操作如果结果为1新的下标只需要移动oldCap位即可
                        // if 01101 & 10000 == 0 -> 根据&newCap-1计算新的下标 01101 & 11111 = 01101
                        // if 11101 & 10000 == 1 -> 根据&newCap-1计算新的下标 11101 & 11111 = 11101
                        if ((e.hash & oldCap) == 0) {
                            if (loTail == null)
                                loHead = e;
                            else
                                loTail.next = e;
                            loTail = e;
                        }
                        else {
                            if (hiTail == null)
                                hiHead = e;
                            else
                                hiTail.next = e;
                            hiTail = e;
                        }
                    } while ((e = next) != null);
                    if (loTail != null) {
                        loTail.next = null;
                        newTab[j] = loHead;
                    }
                    if (hiTail != null) {
                        hiTail.next = null;
                        newTab[j + oldCap] = hiHead;
                    }
                }
            }
        }
    }
    return newTab;
}
```

### TreeMap

TreeMap使用了红黑树来实现，红黑树是一种自平衡的二叉查找树能够保证TreeMap的有序性。  

TreeMap的key不能为Null，value允许为Null。

### LinkedHashMap

LinkedHashMap中的Node在HashMap中的基础上添加了前后节点字段，这样除了如HashMap一样使用哈希表存储元素还维护了一个双向链表，每次插入时还会将元素插入到链表尾部。  

LinkedHashMap也可以通过设置accessOrder来将每次访问的元素移到链表末尾，这样可以用来实现最近最少使用缓存。

```java
public class LRUCache<K, V> extends LinkedHashMap<K, V> {

    private final int cacheSize;

    public LRUCache(int cacheSize) {
        // 使用构造函数初始化 LinkedHashMap，传入三个参数
        // 第一个参数是初始容量，这里设置为 cacheSize * 4 / 3 + 1，以减少扩容次数
        // 第二个参数是负载因子，这里设置为 0.75
        // 第三个参数是 true，表示按访问顺序排序，最近访问的元素放在末尾
        super(cacheSize * 4 / 3 + 1, 0.75f, true);

        this.cacheSize = cacheSize;
    }

    @Override
    protected boolean removeEldestEntry(Map.Entry<K, V> eldest) {
        // 当缓存大小超过设定值时，删除最老的条目
        return size() > cacheSize;
    }
}
```
