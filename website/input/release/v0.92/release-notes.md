---
Title: Release Notes
---

# 0.92 - June 9, 2012 {v0.92}

## NAnt

---

**No Updates since 0.92-rc1**

## NAntContrib

---

### **Bug Fixes**

**Tasks**

* **NUnit2Report** 

  * Fixed graphs so they appear correctly on modern browsers. ([Pull Request #21](https://github.com/nant/nantcontrib/pull/21))  
    Removed # prefix from anchor names. ([Pull Request #20](https://github.com/nant/nantcontrib/pull/20))
  
  
  
# 0.92-rc1 - May 23, 2012 {v0.91-rc1}

## NAnt

---

### **Breaking changes**

**Tasks**

* **XmlPoke**

  * Updated XmlPoke task to honor the *failonerror*{: class="text-primary"} attribute. ([Issue #44](https://github.com/nant/nant/issues/44))

### **Changes**

**Core**

* **NAnt AppDomains**

  * Updated NAnt to use the Unrestricted permission state when creating AppDomains by default instead of just on .NET/Mono 4.0. ([Issue #48](https://github.com/nant/nant/issues/48))

**Tasks**

* **TryCatch**

  * Moved *&lt;trycatch&gt;*{: class="text-primary"} task from NAntContrib to NAnt. ([Issue #26](https://github.com/nant/nant/issues/26))

* **Choose**

  * Moved *&lt;choose&gt;*{: class="text-primary"} task from NAntContrib to NAnt. ([Issue #26](https://github.com/nant/nant/issues/26))
  
  
## NAntContrib

---

### **Changes**

**Tasks**

* **TryCatch**
    
  * Moved *&lt;trycatch&gt;*{: class="text-primary"} task from NAntContrib to NAnt. ([Issue #26](https://github.com/nant/nant/issues/26))

* **Choose**

  * Moved *&lt;choose&gt;*{: class="text-primary"} task from NAntContrib to NAnt. ([Issue #26](https://github.com/nant/nant/issues/26))
  
  
  
# 0.92-beta1 - May 6, 2012 {v0.92-beta1}

**No updates since 0.92-alpha1.**
  
  
  
# 0.92-alpha1 - April 22, 2012 {v0.92-alpha1}

## NAnt

---

### **Changes**

**Framework support**

  * Removed runtime support for .NET/Mono 1.* Frameworks (target support for .NET/Mono 1.* Frameworks still remains)

**Core**

* **NAnt Project Files**

  * Updated NAnt project files to VS2010 format.

* **NUnit**

  * Upgraded to NUnit 2.6.

* **App.Config**

  * Added initial support for Silverlight 5

* **Command Line**

  * Added pause option to pause nant before exit.

* **Type Factory**

  * Added detailed error messages when type loading exception occurs.

**Tasks**

* **Mail**

  * Updated *&lt;mail&gt;*{: class="text-primary"} task to reference System.Net.Mail namespace instead of System.Web.Mail.
  * Added additional attritbutes for greater control of the *&lt;mail&gt;*{: class="text-primary"} task. Such as:

    * mailport
    * ssl
    * user
    * password
    * replyto

* **Zip**

  * Added flatten attribute to *&lt;zip&gt;*{: class="text-primary"} task.

* **Tar**

  * Added flatten attribute to *&lt;tar&gt;*{: class="text-primary"} task.

### **Bug fixes**

**Tasks**

* **Copy/Move tasks**

  * Fixed issues with *&lt;copy&gt;*{: class="text-primary"} and *&lt;move&gt;*{: class="text-primary"} tasks when trying to relocate directories. ([Issue #11](https://github.com/nant/nant/issues/11))

* **Asminfo**

  * Fixed issue with *&lt;asminfo&gt;*{: class="text-primary"} task when trying to add assembly attributes with default constructors. ([Issue #41](https://github.com/nant/nant/issues/41))

* **Style**

  * Updated *&lt;style&gt;*{: class="text-primary"} task to preserve singleton tags whenever possible. ([Issue #17](https://github.com/nant/nant/issues/17))


## NAntContrib

---

### **Changes**

**Core**

* **NAntContrib Project Files**

  * Updated NAntContrib project files to VS2010 format.

**Functions**

* **Array functions**

  * Added Array functions to sort and reverse a string array.

### **Bug fixes**

**Tasks**

* **&lt;iisapppool&gt;**

  * Fixed issue with *&lt;iisapppool&gt;*{: class="text-primary"} encountering access denied error when executing on remote machine. [Issue #6](https://github.com/nant/nantcontrib/issues/6)