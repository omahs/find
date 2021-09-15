// File: ./src/App.js

import React, { useState, useEffect } from "react";
import {AuthCluster} from "./auth-cluster"
import * as fcl from "@onflow/fcl"

export default function App() {
  const [user, setUser] = useState({loggedIn: null})
  useEffect(() => fcl.currentUser().subscribe(setUser), [])


  return (
    <div>
      <AuthCluster user={user}/>
      { user.loggedIn && (
        <div>Foo</div>
      )}
    </div>
  )
}