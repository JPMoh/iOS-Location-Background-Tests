//
//  ViewController.swift
//  LocationBackgroundTimerApp
//
//  Created by John Mohler on 8/30/16.
//  Copyright © 2016 John Mohler. All rights reserved.
//

import UIKit
import CoreLocation
import CoreData
import CoreBluetooth

class ViewController: UIViewController, CLLocationManagerDelegate, UITableViewDataSource, UITableViewDelegate, CBCentralManagerDelegate {

    let DATEFORMAT : String = "dd-MM-yyyy, HH:mm:ss"
    var locationTimes = [String]()

    
    @IBOutlet weak var tableView: UITableView!
    //- Time intervals for scan
    var UpdatesInterval : NSTimeInterval = 10*60
    var KeepAliveTimeInterval : Double = 20*60 // App gets a new location every 5 minutes to keep timers alive
    
    //- NSTimer object for scheduling accuracy changes
    var timer = NSTimer()
    
    //- Controls button calls
    var updatesEnabled = false
    
    //- Location Manager - CoreLocation Framework
    let locationManager = CLLocationManager()
    
    //- DataManager Object - Manages data in memory based on the CoreData framework
    
    //- UIBackgroundTask
    var bgTask = UIBackgroundTaskInvalid
    
    //- NSNotificationCenter to handle changes in App LifeCycle
    var defaultCentre: NSNotificationCenter = NSNotificationCenter.defaultCenter()
    
    //- NSUserDefaults - LocationServicesControl_KEY to be set to TRUE when user has enabled location services.
    let UserDefaults: NSUserDefaults = NSUserDefaults.standardUserDefaults()
    let LocationServicesControl_KEY: String = "LocationServices"

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cell")

        print("view did load")
        
        self.locationManager.delegate = self
        
        //- Authorization for utilization of location services for background process
        if (CLLocationManager.authorizationStatus() != CLAuthorizationStatus.AuthorizedAlways) {
            self.locationManager.requestAlwaysAuthorization()
        }
        // END: Location Manager configuration ---------------------------------------------------------------------
        
        //- NSNotificationCenter configuration for handling transitions in the App's Lifecycle
        
        self.defaultCentre.addObserver(self, selector: #selector(ViewController.appWillTerminate(_:)), name: UIApplicationWillTerminateNotification, object: nil)
        self.defaultCentre.addObserver(self, selector: #selector(ViewController.appIsRelaunched(_:)), name: UIApplicationDidFinishLaunchingNotification, object: nil)
        
        
        self.centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)

        startLocationServices()
        // Do any additional setup after loading the view, typically from a nib.
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return locationTimes.count
    }
    
    // create a cell for each table view row
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        // create a new cell if needed or reuse an old one
        let cell:UITableViewCell = self.tableView.dequeueReusableCellWithIdentifier("cell") as UITableViewCell!
        
        // set the text from the data model
        cell.textLabel?.text = locationTimes[indexPath.row]
        
        return cell
    }
    
    // method to run when table view cell is tapped
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        print("You tapped cell number \(indexPath.row).")
    }

    func setIntervals(updatesInterval: NSTimeInterval){ self.UpdatesInterval = updatesInterval;}
    func setKeepAlive(keepAlive: Double){ self.KeepAliveTimeInterval = keepAlive;}
    func getIntervals() -> NSTimeInterval { return self.UpdatesInterval}
    func getKeepAlive() -> Double { return self.KeepAliveTimeInterval}
    func areUpdatesEnabled() -> Bool {return self.updatesEnabled}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func startLocationServices() {
        
        if (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.AuthorizedAlways){
            
            if (!self.updatesEnabled){
                //- Location Accuracy, properties & Distance filter
                self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
                self.locationManager.distanceFilter = kCLDistanceFilterNone
                self.locationManager.allowsBackgroundLocationUpdates = true
                
                //- Start receiving location updates
                self.locationManager.startUpdatingLocation()
                
                self.updatesEnabled = true;
                
                //- Save Location Services ENABLED to NSUserDefaults
                self.UserDefaults.setBool(true, forKey: self.LocationServicesControl_KEY)
                print("Location Updates started")
                
            } else {
                print("Location Updates already enabled")
            }
            
        } else {
            
            print("Application is not authorized to use location services")
            //- TODO: Unauthorized, requests permissions again and makes recursive call
        }
    }

    /********************************************************************************************************************
     METHOD NAME: changeLocationAccuracy
     INPUT PARAMETERS: None
     RETURNS: None
     
     OBSERVATIONS: Toggles location manager's accuracy to save battery when waiting for timer to expire
     ********************************************************************************************************************/
    func changeLocationAccuracy (){
        
        let CurrentAccuracy = self.locationManager.desiredAccuracy
        
        switch CurrentAccuracy {
            
        case kCLLocationAccuracyBest: //- Decreses Accuracy
            
            self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            self.locationManager.distanceFilter = 99999
            
        case kCLLocationAccuracyThreeKilometers: //- Increaces Accuracy
            
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager.distanceFilter = kCLDistanceFilterNone
            
        default:
            print("Accuracy not Changed")
        }
    }
    /********************************************************************************************************************
     METHOD NAME: isUpdateValid
     INPUT PARAMETERS: NSDate object
     RETURNS: Bool
     
     OBSERVATIONS: Returns true newDate input parameter is an NSDate with a time interval difference of 3600 (60 minutes).
     If zero returns true as no other records are in memory. Else returns false (invalid update)
     ********************************************************************************************************************/
    // =====================================     NSNotificationCenter Methods (App LifeCycle)  ====================//
    /********************************************************************************************************************
     METHOD NAME: appWillTerminate
     INPUT PARAMETERS: NSNotification object
     RETURNS: None
     
     OBSERVATIONS: The AppDelegate triggers this method when the App is about to be terminated (Removed from memory due to
     a crash or due to the user killing the app from the multitasking feature). This call causes the plugin to stop
     standard location services if running, and enable significant changes to re-start the app as soon as possible.
     ********************************************************************************************************************/
    func appWillTerminate (notification: NSNotification){
        
        print("app terminated")
        let ServicesEnabled = self.UserDefaults.boolForKey(self.LocationServicesControl_KEY)
        
        //- Stops Standard Location Services if they have been enabled by the user
        if ServicesEnabled {
            
            //- Stop Location Updates
            self.locationManager.stopUpdatingLocation()
            
            //- Stops Timer
            self.timer.invalidate()
            
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest

            //- Enables Significant Location Changes services to restart the app ASAP
            self.locationManager.startMonitoringSignificantLocationChanges()
        }
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    /********************************************************************************************************************
     METHOD NAME: appIsRelaunched
     INPUT PARAMETERS: NSNotification object
     RETURNS: None
     
     OBSERVATIONS: This method is called by the AppDelegate when the app starts. This method will stop the significant
     change location updates and restart the standard location services if they where previously running (Checks saved
     NSUserDefaults)
     ********************************************************************************************************************/
    func appIsRelaunched (notification: NSNotification) {
        
        print("app is relaunched")
        //- Stops Significant Location Changes services when app is relaunched
        self.locationManager.stopMonitoringSignificantLocationChanges()
        
        let ServicesEnabled = self.UserDefaults.boolForKey(self.LocationServicesControl_KEY)
        
        //- Re-Starts Standard Location Services if they have been enabled by the user
        if (ServicesEnabled) {

            self.startLocationServices()
        }
    }
    // =====================================     CLLocationManager Delegate Methods    ===========================//
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        print("did update locations")

        let qualityOfServiceClass = QOS_CLASS_BACKGROUND
        let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)
        dispatch_async(backgroundQueue, {
            
            if self.currentlyScanningBLE == false {
                self.scanBLENow()
            }
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                print("This is run on the main queue, after the previous code in outer block")
            })
        })

        self.bgTask = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({
            UIApplication.sharedApplication().endBackgroundTask(self.bgTask)
            self.bgTask = UIBackgroundTaskInvalid
        })
        
        //- parse last known location
        let newLocation = locations.last!
        
        // Filters bad location updates cached by the OS -----------------------------------------------------------
        let Interval: NSTimeInterval = newLocation.timestamp.timeIntervalSinceNow
        
        let accuracy = self.locationManager.desiredAccuracy
        
        if ((abs(Interval)<5)&&(accuracy != kCLLocationAccuracyThreeKilometers)) {
            
            //- Updates Persistent records through the DataManager object
            postJSON(createJSONObject())
            locationTimes.append("\(NSDate())")

            /* Timer initialized everytime an update is received. When timer expires, reverts accuracy to HIGH, thus
             enabling the delegate to receive new location updates */
            self.timer = NSTimer.scheduledTimerWithTimeInterval(self.KeepAliveTimeInterval, target: self, selector: #selector(ViewController.changeLocationAccuracy), userInfo: nil, repeats: false)
            
            //- Lowers accuracy to avoid battery drainage
            self.changeLocationAccuracy()
        }
        
        tableView.reloadData()

        // END: Filters bad location updates cached by the OS ------------------------------------------------------
    }
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        
        if status == CLAuthorizationStatus.AuthorizedAlways || status == CLAuthorizationStatus.AuthorizedWhenInUse {
         
            startLocationServices()

        }
    }
    
    func createJSONObject() -> [String: AnyObject] {
  
    let jSONObject: [String: AnyObject] = ["ids": ["ios_ifa^A79E8910-442B-4435-9FC8-A70F598158E6"],
    "lat" : -22.22,
    "lon" : 33.33,
    "token": "F3zm2tAvr7+Aei5G6QCD15Osr/ifXHrnFswJ6eSACRk=",
    "timepoint": String(currentTimeMillis()),
    "metadata" : ["device:iPhone 6", "sdk:ios-swift-1.0", "app:LocationBacgkroundTimerApp", "cWifi:JP Fake Wifi"],
    "observed": [["tech" : "ble",
        "rssi" : -95,
        "name" : "HTC BS 5FE6D6:8F440A94-29EE-DCE2-13CE-41DF1072AE0C"]]
    ]
        
        return jSONObject
    }
    
    func bluetoothScan() {
        
    }
    
    func currentTimeMillis() -> Int64{
        let nowDouble = NSDate().timeIntervalSince1970
        return Int64(nowDouble)
    }

    
    func postJSON(jsondictionary: [String: AnyObject]) {
        do {
            
            let jsonData = try NSJSONSerialization.dataWithJSONObject(jsondictionary, options: NSJSONWritingOptions.PrettyPrinted)
            
            let url = NSURL(string: "https://pie.wirelessregistry.com/observation/")
            let request = NSMutableURLRequest(URL: url!)
            
            request.HTTPMethod = "POST"
            request.HTTPBody = jsonData
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            
            NSLog("\(NSString(data: jsonData, encoding: NSUTF8StringEncoding)!)")
            NSLog("stringjsondata")
            
            let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { (data, response, error) -> Void in
                
                if let unwrappedError = error {
                    NSLog("error=\(unwrappedError)")
                    
                }
                else {
                    if let _ = data {
                        
                        NSLog("\(response)")
                        NSLog("success response")
                        return
                    }
                }
                
            }
            
            task.resume()
        }
            
        catch _ as NSError {
            
            NSLog("error")
        }

    }
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        print("Location update error: \(error.localizedDescription)")
    }
    
    ///CB Protocol
    
    private var centralManager : CBCentralManager = CBCentralManager()
    private var deviceInformationServiceUUID : CBUUID = CBUUID(string:"180A")
    private var tileUUID1 : CBUUID = CBUUID(string:"FEED")
    private var tileUUID2 : CBUUID = CBUUID(string:"FEEC")
    private var currentlyScanningBLE = false
    func scanBLENow() {
       
        currentlyScanningBLE = true
        centralManager.scanForPeripheralsWithServices([tileUUID1, tileUUID2,deviceInformationServiceUUID] , options: nil)
        sleep(UInt32(15))
        centralManager.stopScan()
        currentlyScanningBLE = false
    
    }
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        
        NSLog("centralmanagerdidupdatestate")
        switch (central.state) {
        case .Unsupported:
            NSLog("unsupported")
        case .Unauthorized:
            NSLog("unauthorize")
        case .Resetting:
            NSLog("resetting")
        case .PoweredOff:
            NSLog("poweredoff")
        case .PoweredOn:
            NSLog("powered on")
        default:
            NSLog("default")
        }
        
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        NSLog("found a peripheral")
        
    }

    
}




