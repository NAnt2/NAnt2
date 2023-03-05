<%@ Page Title="Phone Number" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="AddPhoneNumber.aspx.cs" Inherits="WebApplication.Account.AddPhoneNumber" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <main aria-labelledby="title">
        <h2 id="title"><%: Title %>.</h2>
        <h4>Add a phone number</h4>
        <hr />
        <asp:ValidationSummary runat="server" CssClass="text-danger" />
        <p class="text-danger">
            <asp:Literal runat="server" ID="ErrorMessage" />
        </p>
        <div class="row">
            <asp:Label runat="server" AssociatedControlID="PhoneNumber" CssClass="col-md-2 col-form-label">Phone Number</asp:Label>
            <div class="col-md-10">
                <asp:TextBox runat="server" ID="PhoneNumber" CssClass="form-control" TextMode="Phone" />
                <asp:RequiredFieldValidator runat="server" ControlToValidate="PhoneNumber"
                    CssClass="text-danger" ErrorMessage="The PhoneNumber field is required." />
            </div>
        </div>
        <div class="form-group">
            <div class="offset-md-2 col-md-10">
                <asp:Button runat="server" OnClick="PhoneNumber_Click"
                    Text="Submit" CssClass="btn btn-outline-dark" />
            </div>
        </div>
    </main>
</asp:Content>
